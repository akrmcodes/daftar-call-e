import 'dart:async';

import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/data/datasources/remote/drive_refreshing_http_client.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/data/datasources/remote/google_id_token_expiry.dart';
import 'package:daftar/data/datasources/remote/google_token_refresh_client.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/constants/auth_session_constants.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Outcome of user-gesture ID-token hydration for the linked Google session.
sealed class LinkedIdTokenHydration {
  const LinkedIdTokenHydration();
}

/// A usable Google ID token for the linked `googleUserId`.
final class LinkedIdTokenReady extends LinkedIdTokenHydration {
  /// Creates a ready result.
  const LinkedIdTokenReady(this.token);

  /// Bearer token (`aud` = Web client ID from GSI, or the installed-app
  /// client ID from PKCE refresh).
  final String token;
}

/// No ID token could be produced without opening a picker.
final class LinkedIdTokenMissing extends LinkedIdTokenHydration {
  /// Creates a missing result.
  const LinkedIdTokenMissing();
}

/// Drive PKCE grant exists but lacks `openid` — one-time AppAuth re-consent.
final class LinkedIdTokenNeedsOpenIdGrant extends LinkedIdTokenHydration {
  /// Creates an upgrade-required result.
  const LinkedIdTokenNeedsOpenIdGrant();
}

/// PKCE-minted ID token `sub` does not match the linked `googleUserId`.
final class LinkedIdTokenMismatch extends LinkedIdTokenHydration {
  /// Creates a mismatch result.
  const LinkedIdTokenMismatch();
}

/// Availability of headless Drive credentials after a non-interactive attempt.
enum DriveCredentialStatus {
  /// A valid access token is cached in the secure bundle — Drive I/O may run.
  ready,

  /// The stored refresh token was revoked server-side — interactive re-auth
  /// is genuinely required.
  revoked,

  /// No credential could be produced right now (offline, transient error, or
  /// no offline grant stored) — defer and retry later.
  unavailable,
}

/// Remote data source wrapping Google Sign-In for Drive `appDataFolder` access.
///
/// Auth V2 persistence-first: session metadata lives in [AuthSessionStore];
/// this class hydrates the Google Sign-In SDK from the stored bundle.
///
/// ## Session Tracking (Google Sign-In v7)
///
/// `GoogleSignIn.instance` no longer exposes a stable "current user".
/// `_cachedAccount` mirrors [GoogleSignIn.authenticationEvents] and is
/// re-hydrated on demand by [signInSilently].
///
/// ## Headless token renewal (PKCE offline grant)
///
/// [ensureDriveCredential] mints fresh access tokens from the stored refresh
/// token via pure HTTP — no Activity, no platform channels — so Drive backup
/// keeps working in Workmanager isolates indefinitely.
class GoogleAuthDs {
  GoogleAuthDs({
    required AuthSessionStore authSessionStore,
    GoogleTokenRefreshClient? tokenRefreshClient,
  })  : _authSessionStore = authSessionStore,
        _tokenRefreshClient = tokenRefreshClient ?? GoogleTokenRefreshClient();

  static const Duration _silentRetryDelay = Duration(milliseconds: 500);
  static const Duration _streamHydrationTimeout = Duration(seconds: 8);
  static const Duration _interactiveSignInTimeout = Duration(minutes: 3);
  static const Duration _silentAuthorizationTimeout = Duration(seconds: 20);
  static const Duration _lightweightAuthTimeout = Duration(seconds: 12);

  final AuthSessionStore _authSessionStore;
  final GoogleTokenRefreshClient _tokenRefreshClient;

  GoogleSignInAccount? _cachedAccount;
  GoogleSignInClientAuthorization? _pendingInteractiveAuthorization;
  Future<void>? _initFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;
  List<String> _activeScopes = AuthScopes.defaultDriveBackupScopes;

  /// Active Drive scopes for the current session.
  List<String> get scopes => _activeScopes;

  /// Ensures Google Sign-In is initialized from the secure session bundle.
  Future<void> ensureInitialized() {
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  Future<void> _initialize() async {
    final bundle = await _authSessionStore.read();
    final serverClientId = bundle?.serverClientId ?? _requireServerClientId();
    _activeScopes = bundle?.scopesGranted ?? AuthScopes.defaultDriveBackupScopes;

    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _authEventsSub ??= GoogleSignIn.instance.authenticationEvents.listen(
      _onAuthenticationEvent,
      onError: (Object _) {},
    );
    // Never call attemptLightweightAuthentication here — on Android it can
    // open Credential Manager One Tap while the user is already linked.
  }

  String _requireServerClientId() {
    final serverClientId = Env.googleServerClientId;
    if (serverClientId.isEmpty || serverClientId == 'PUT_WEB_CLIENT_ID_HERE') {
      throw const GoogleAuthConfigurationException(
        'GOOGLE_SERVER_CLIENT_ID is not configured. Add a Web application '
        'OAuth client id to .env and regenerate envied code.',
      );
    }
    return serverClientId;
  }

  void _onAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    _cachedAccount = switch (event) {
      GoogleSignInAuthenticationEventSignIn(:final user) => user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
  }

  /// Interactive Google sign-in.
  ///
  /// Uses the official Google Sign-In v7 flow only:
  /// 1. `authenticate(scopeHint:)` — account picker (combined authz when
  ///    the platform supports it)
  /// 2. Silent `authorizationForScopes` — Drive `appdata` token if already
  ///    granted (never `authorizeScopes` here — that second sheet after the
  ///    picker often fails on Android; offline PKCE is a separate tap)
  ///
  /// Does **not** open AppAuth / Custom Tabs. Offline PKCE for headless
  /// Workmanager is a separate user action via the Drive authorization
  /// banner (`AuthRepository.completeDriveAuthorization`).
  ///
  /// Does not persist the session bundle — the caller must invoke
  /// [persistSessionBundle] after any account-switch ceremony completes.
  ///
  /// Returns null if the user cancels (no exception for soft cancel codes).
  Future<GoogleSignInAccount?> signIn() async {
    await ensureInitialized();
    const scopeHint = AuthScopes.defaultDriveBackupScopes;
    try {
      final account = await GoogleSignIn.instance
          .authenticate(scopeHint: scopeHint)
          .timeout(_interactiveSignInTimeout);
      _activeScopes = scopeHint;
      _cachedAccount = account;
      _pendingInteractiveAuthorization =
          await _resolveInteractiveDriveAuthorization(account, scopeHint);
      return account;
    } on TimeoutException {
      _pendingInteractiveAuthorization = null;
      throw const GoogleAuthTimeoutException();
    } on GoogleSignInException catch (e) {
      _pendingInteractiveAuthorization = null;
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      rethrow;
    }
  }

  /// Resolves a Drive access token via silent GSI authorization only.
  ///
  /// Never calls `authorizeScopes` — chaining a consent sheet after
  /// `authenticate()` loses the Android Activity/user-gesture chain and
  /// produces a dead second Google UI. When scopes are not yet granted,
  /// returns null; the caller persists the identity session and the UI
  /// surfaces “Complete Drive authorization” (AppAuth PKCE) as a fresh
  /// user gesture.
  Future<GoogleSignInClientAuthorization?>
      _resolveInteractiveDriveAuthorization(
    GoogleSignInAccount account,
    List<String> scopes,
  ) async {
    try {
      return await account.authorizationClient
          .authorizationForScopes(scopes)
          .timeout(_silentAuthorizationTimeout, onTimeout: () => null);
    } on TimeoutException {
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      rethrow;
    }
  }

  /// Writes the Auth V2 session bundle for [account] after interactive sign-in.
  ///
  /// When [authorization] is omitted, uses the authorization captured by the
  /// most recent [signIn] call. All metadata and the OAuth access token are
  /// persisted in a single atomic [AuthSessionStore.write].
  ///
  /// Preserves an existing PKCE offline grant when the same Google user is
  /// re-linked so silent/resume paths cannot wipe headless credentials.
  Future<void> persistSessionBundle(
    GoogleSignInAccount account, {
    GoogleSignInClientAuthorization? authorization,
  }) async {
    const scopeHint = AuthScopes.defaultDriveBackupScopes;
    final resolvedAuthorization =
        authorization ?? _pendingInteractiveAuthorization;
    _pendingInteractiveAuthorization = null;

    final existing = await _authSessionStore.read();
    final now = DateTime.now().toUtc();
    final grantedScopes = existing != null &&
            existing.googleUserId == account.id &&
            existing.hasOpenIdOfflineGrant
        ? existing.scopesGranted
        : scopeHint;
    var bundle = AuthSessionBundle.create(
      googleUserId: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      serverClientId: _requireServerClientId(),
      scopesGranted: grantedScopes,
      linkedAt: existing?.googleUserId == account.id
          ? existing!.linkedAt
          : now,
      lastSuccessfulSilentAuthAt: now,
    );

    if (existing != null &&
        existing.googleUserId == account.id &&
        existing.hasDriveOfflineGrant) {
      bundle = bundle.withDriveOfflineGrant(
        refreshToken: existing.driveRefreshToken!,
        clientId: existing.driveTokenClientId!,
      );
      if (existing.hasValidCachedAccessToken &&
          existing.cachedAccessToken != null) {
        bundle = bundle.withCachedAccessToken(
          existing.cachedAccessToken!,
          expiresAt: existing.cachedAccessTokenExpiresAt,
        );
      }
    }

    bundle = _withIdTokenFromAccount(bundle, account, existing);

    await _authSessionStore.write(bundle);
    _activeScopes = grantedScopes;
    _cachedAccount = account;

    if (resolvedAuthorization != null) {
      await _verifyAndCacheGsiToken(resolvedAuthorization.accessToken);
    }
  }

  /// Validates a token handed out by the Google Sign-In SDK before trusting
  /// it, because the Android authorization cache can return tokens that are
  /// already expired or revoked (documented platform limitation).
  ///
  /// Returns true when a usable token ended up cached in the secure bundle.
  Future<bool> _verifyAndCacheGsiToken(String accessToken) async {
    final introspection = await _tokenRefreshClient.introspect(accessToken);
    switch (introspection) {
      case GoogleTokenIntrospectionValid(:final expiresAt):
        await _authSessionStore.updateCachedAccessToken(
          accessToken,
          expiresAt: expiresAt,
        );
        return true;
      case GoogleTokenIntrospectionInvalid():
        await _clearSdkAuthorizationToken(accessToken);
        return false;
      case GoogleTokenIntrospectionUnavailable():
        await _authSessionStore.updateCachedAccessToken(accessToken);
        return true;
    }
  }

  Future<void> _clearSdkAuthorizationToken(String accessToken) async {
    try {
      await GoogleSignIn.instance.authorizationClient
          .clearAuthorizationToken(accessToken: accessToken);
    } on Object {
      // Cache clearing is best-effort; the bundle no longer holds the token.
    }
  }

  /// Restores a Google session without forcing an interactive sign-in.
  ///
  /// When an Auth V2 session bundle already exists, this never calls
  /// `attemptLightweightAuthentication` (Android One Tap / account sheet).
  /// Callers with a linked bundle must refresh via PKCE
  /// [ensureDriveCredential] or a cached GSI account only.
  Future<GoogleSignInAccount?> signInSilently() async {
    final bundle = await _authSessionStore.read();
    if (bundle != null && bundle.hasValidCachedAccessToken) {
      return _cachedAccount;
    }

    await ensureInitialized();
    if (_cachedAccount != null) {
      return _finalizeSilentSession(_cachedAccount!);
    }

    // Linked session: never open Credential Manager One Tap.
    if (bundle != null) {
      return null;
    }

    // No bundle (migration / first cold start only): lightweight may run.
    var restored = await _lightweightRestore();
    if (restored != null) {
      return _finalizeSilentSession(restored);
    }

    await Future<void>.delayed(_silentRetryDelay);
    restored = await _lightweightRestore();
    if (restored != null) {
      return _finalizeSilentSession(restored);
    }

    return null;
  }

  Future<GoogleSignInAccount?> _finalizeSilentSession(
    GoogleSignInAccount account,
  ) async {
    final bundle = await _authSessionStore.read();
    if (bundle != null && account.id != bundle.googleUserId) {
      return null;
    }

    final scopes = bundle?.scopesGranted ?? _activeScopes;
    await _cacheAccessTokenFromAccount(account, scopes);

    if (bundle != null) {
      await _authSessionStore.updateLastSuccessfulSilentAuthAt(
        DateTime.now().toUtc(),
      );
    }

    _cachedAccount = account;
    return account;
  }

  Future<GoogleSignInAccount?> _lightweightRestore() async {
    if (_cachedAccount != null) {
      return _cachedAccount;
    }
    try {
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt == null) {
        return _awaitStreamSignIn();
      }
      unawaited(
        attempt.then((account) {
          if (account != null) {
            _cachedAccount = account;
          }
        }),
      );
      final account = await attempt.timeout(
        _lightweightAuthTimeout,
        onTimeout: () => null,
      );
      if (account != null) {
        _cachedAccount = account;
      }
      return _cachedAccount ?? await _awaitStreamSignIn();
    } on Object {
      return _cachedAccount;
    }
  }

  Future<GoogleSignInAccount?> _awaitStreamSignIn() async {
    if (_cachedAccount != null) {
      return _cachedAccount;
    }
    try {
      await GoogleSignIn.instance.authenticationEvents
          .firstWhere((event) => event is GoogleSignInAuthenticationEventSignIn)
          .timeout(_streamHydrationTimeout);
    } on Object {
      // No sign-in arrived in the window; treat as signed out.
    }
    return _cachedAccount;
  }

  Future<void> _cacheAccessTokenFromAccount(
    GoogleSignInAccount account,
    List<String> scopes,
  ) async {
    try {
      final authorization = await account.authorizationClient
          .authorizationForScopes(scopes)
          .timeout(_silentAuthorizationTimeout, onTimeout: () => null);
      if (authorization == null) {
        return;
      }
      final cached = await _verifyAndCacheGsiToken(authorization.accessToken);
      if (cached) {
        return;
      }
      final retried = await account.authorizationClient
          .authorizationForScopes(scopes)
          .timeout(_silentAuthorizationTimeout, onTimeout: () => null);
      if (retried != null &&
          retried.accessToken != authorization.accessToken) {
        await _verifyAndCacheGsiToken(retried.accessToken);
      }
    } on Object {
      // Non-fatal — cached token refresh during warm session only.
    }
  }

  /// Public silent Drive token cache for an already-linked account.
  ///
  /// Never prompts and never opens AppAuth.
  Future<void> cacheDriveAccessTokenSilently(
    GoogleSignInAccount account,
  ) async {
    await _cacheAccessTokenFromAccount(
      account,
      AuthScopes.defaultDriveBackupScopes,
    );
  }

  /// Whether [scopes] are already authorized for [account] without prompting.
  Future<bool> hasDriveScopesAuthorized(GoogleSignInAccount account) async {
    final authorization = await account.authorizationClient
        .authorizationForScopes(scopes)
        .timeout(_silentAuthorizationTimeout, onTimeout: () => null);
    return authorization != null;
  }

  /// Signs out of the SDK and deletes the secure session bundle.
  Future<void> signOut() async {
    await ensureInitialized();
    _cachedAccount = null;
    _pendingInteractiveAuthorization = null;
    await _authSessionStore.delete();
    try {
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Bundle is already deleted — SDK sign-out failure is non-fatal.
    }
  }

  /// Releases the [GoogleSignIn.authenticationEvents] subscription.
  Future<void> dispose() async {
    await _authEventsSub?.cancel();
    _authEventsSub = null;
    _initFuture = null;
  }

  /// Whether the data source currently holds a signed-in account reference.
  bool isSignedIn() => _cachedAccount != null;

  /// Returns the last known signed-in account, if any.
  GoogleSignInAccount? getAccount() => _cachedAccount;

  /// Obtains a Google ID token for Cloud Run / the Stage 8 Auth Bridge.
  ///
  /// GSI v7 issues [GoogleSignInAuthentication.idToken] at authentication
  /// time only — tokens expire (~1 hour). Android has no guaranteed silent
  /// ID-token refresh; `attemptLightweightAuthentication` can open One Tap.
  ///
  /// Automatic paths (`allowInteractive: false`) never call lightweight
  /// restore and never `authenticate()`. Order:
  /// 1. Warm `_cachedAccount` ID token (unexpired)
  /// 2. Unexpired bundle `cachedIdToken`
  /// 3. Interactive [signIn] only when [allowInteractive] is true
  /// 4. Otherwise `null` (fail-closed — no Google UI)
  ///
  /// User-initiated Closing Agent Send uses [hydrateLinkedIdToken] instead of
  /// passing `allowInteractive: true`. That path mints a new ID token from
  /// the PKCE refresh token — never GSI One Tap.
  Future<String?> obtainIdToken({bool allowInteractive = false}) async {
    final warmToken = _unexpiredIdTokenFromAccount(_cachedAccount);
    if (warmToken != null) {
      await _persistIdTokenIfLinked(warmToken);
      return warmToken;
    }

    final bundleToken = await _idTokenFromBundle();
    if (bundleToken != null) {
      return bundleToken;
    }

    if (!allowInteractive) {
      return null;
    }

    final interactiveAccount = await signIn();
    final interactiveToken = _idTokenFromAccount(interactiveAccount);
    if (interactiveToken != null) {
      await _persistIdTokenIfLinked(interactiveToken);
    }
    return interactiveToken;
  }

  /// User-initiated ID token restore for the linked Google user only.
  ///
  /// Silent HTTP via the PKCE refresh token when the grant includes `openid`.
  /// NEVER calls `attemptLightweightAuthentication` or `authenticate()` —
  /// those APIs open Credential Manager / an account picker on Android.
  /// Caller must be a user gesture (agent Send).
  Future<LinkedIdTokenHydration> hydrateLinkedIdToken() async {
    final existing = await obtainIdToken();
    if (existing != null && existing.isNotEmpty) {
      return LinkedIdTokenReady(existing);
    }

    final bundle = await _authSessionStore.read();
    if (bundle == null) {
      return const LinkedIdTokenMissing();
    }

    if (bundle.hasOpenIdOfflineGrant) {
      return _hydrateIdTokenFromPkce(bundle);
    }

    if (bundle.hasDriveOfflineGrant) {
      return const LinkedIdTokenNeedsOpenIdGrant();
    }

    return const LinkedIdTokenMissing();
  }

  Future<LinkedIdTokenHydration> _hydrateIdTokenFromPkce(
    AuthSessionBundle bundle,
  ) async {
    final result = await _tokenRefreshClient.refresh(
      clientId: bundle.driveTokenClientId!,
      refreshToken: bundle.driveRefreshToken!,
    );
    switch (result) {
      case GoogleTokenRefreshSuccess(
          :final accessToken,
          :final expiresAt,
          :final rotatedRefreshToken,
          :final idToken,
        ):
        await _persistPkceRefreshSuccess(
          bundle: bundle,
          accessToken: accessToken,
          expiresAt: expiresAt,
          rotatedRefreshToken: rotatedRefreshToken,
          idToken: idToken,
        );
        if (idToken == null || idToken.isEmpty) {
          return const LinkedIdTokenNeedsOpenIdGrant();
        }
        final subject = googleIdTokenSubject(idToken);
        if (subject != null && subject != bundle.googleUserId) {
          return const LinkedIdTokenMismatch();
        }
        return LinkedIdTokenReady(idToken);
      case GoogleTokenRefreshRevoked():
      case GoogleTokenRefreshTransient():
        return const LinkedIdTokenMissing();
    }
  }

  String? _idTokenFromAccount(GoogleSignInAccount? account) {
    final idToken = account?.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      return null;
    }
    return idToken;
  }

  String? _unexpiredIdTokenFromAccount(GoogleSignInAccount? account) {
    final idToken = _idTokenFromAccount(account);
    if (idToken == null) {
      return null;
    }
    final expiresAt = googleIdTokenExpiry(idToken);
    if (expiresAt == null) {
      return idToken;
    }
    final now = DateTime.now().toUtc();
    if (!now.isBefore(
      expiresAt.subtract(AuthSessionConstants.accessTokenExpirySafetyMargin),
    )) {
      return null;
    }
    return idToken;
  }

  Future<String?> _idTokenFromBundle() async {
    final bundle = await _authSessionStore.read();
    if (bundle == null || !bundle.hasValidCachedIdToken) {
      return null;
    }
    return bundle.cachedIdToken;
  }

  AuthSessionBundle _withIdTokenFromAccount(
    AuthSessionBundle bundle,
    GoogleSignInAccount account,
    AuthSessionBundle? existing,
  ) {
    final idToken = _idTokenFromAccount(account);
    if (idToken != null) {
      return bundle.withCachedIdToken(
        idToken,
        expiresAt: _idTokenExpiresAt(idToken),
      );
    }
    if (existing != null &&
        existing.googleUserId == account.id &&
        existing.hasValidCachedIdToken &&
        existing.cachedIdToken != null) {
      return bundle.withCachedIdToken(
        existing.cachedIdToken!,
        expiresAt: existing.cachedIdTokenExpiresAt,
      );
    }
    return bundle;
  }

  DateTime _idTokenExpiresAt(String idToken) {
    return googleIdTokenExpiry(idToken) ??
        DateTime.now().toUtc().add(AuthSessionConstants.cachedAccessTokenTtl);
  }

  Future<void> _persistIdTokenIfLinked(String idToken) async {
    final bundle = await _authSessionStore.read();
    if (bundle == null) {
      return;
    }
    if (bundle.cachedIdToken == idToken && bundle.hasValidCachedIdToken) {
      return;
    }
    await _authSessionStore.updateCachedIdToken(
      idToken,
      expiresAt: _idTokenExpiresAt(idToken),
    );
  }

  /// Returns an HTTP client from secure-bundle Bearer token only.
  ///
  /// Never touches [GoogleSignIn.instance] — safe for screen mount when the
  /// cached OAuth token from interactive link is still within TTL. The
  /// returned client self-heals on 401 via the PKCE refresh token.
  Future<http.Client?> tryClientFromCachedBundle() async {
    final bundle = await _authSessionStore.read();
    if (bundle == null || !bundle.hasValidCachedAccessToken) {
      return null;
    }
    return _refreshingClient();
  }

  /// Ensures a valid Drive access token exists in the secure bundle without
  /// any UI: cached token first, then PKCE refresh-token exchange.
  ///
  /// Pure HTTP — no platform channels, no Activity — safe in headless
  /// Workmanager isolates regardless of how long the app has been killed.
  Future<DriveCredentialStatus> ensureDriveCredential() async {
    final bundle = await _authSessionStore.read();
    if (bundle == null) {
      return DriveCredentialStatus.unavailable;
    }
    if (bundle.hasValidCachedAccessToken) {
      return DriveCredentialStatus.ready;
    }
    if (!bundle.hasDriveOfflineGrant) {
      return DriveCredentialStatus.unavailable;
    }

    final result = await _tokenRefreshClient.refresh(
      clientId: bundle.driveTokenClientId!,
      refreshToken: bundle.driveRefreshToken!,
    );
    switch (result) {
      case GoogleTokenRefreshSuccess(
          :final accessToken,
          :final expiresAt,
          :final rotatedRefreshToken,
          :final idToken,
        ):
        await _persistPkceRefreshSuccess(
          bundle: bundle,
          accessToken: accessToken,
          expiresAt: expiresAt,
          rotatedRefreshToken: rotatedRefreshToken,
          idToken: idToken,
        );
        return DriveCredentialStatus.ready;
      case GoogleTokenRefreshRevoked():
        return DriveCredentialStatus.revoked;
      case GoogleTokenRefreshTransient():
        return DriveCredentialStatus.unavailable;
    }
  }

  Future<void> _persistPkceRefreshSuccess({
    required AuthSessionBundle bundle,
    required String accessToken,
    required DateTime? expiresAt,
    required String? rotatedRefreshToken,
    required String? idToken,
  }) async {
    await _authSessionStore.updateCachedAccessToken(
      accessToken,
      expiresAt: expiresAt,
    );
    if (rotatedRefreshToken != null) {
      await _authSessionStore.updateDriveOfflineGrant(
        refreshToken: rotatedRefreshToken,
        clientId: bundle.driveTokenClientId!,
        scopesGranted: bundle.hasOpenIdOfflineGrant
            ? AuthScopes.pkceOfflineGrantScopes
            : null,
      );
    }
    if (idToken != null && idToken.isNotEmpty) {
      final subject = googleIdTokenSubject(idToken);
      if (subject == null || subject == bundle.googleUserId) {
        await _persistIdTokenIfLinked(idToken);
      }
    }
    await _authSessionStore.updateLastSuccessfulSilentAuthAt(
      DateTime.now().toUtc(),
    );
  }

  /// Returns an authorized client from the bundle, refreshing via the PKCE
  /// offline grant when the cached token is stale.
  ///
  /// Throws [GoogleDriveGrantRevokedException] when the refresh token is
  /// permanently dead; returns null for transient unavailability.
  Future<http.Client?> tryClientFromBundleOrRefresh() async {
    final cached = await tryClientFromCachedBundle();
    if (cached != null) {
      return cached;
    }
    final status = await ensureDriveCredential();
    return switch (status) {
      DriveCredentialStatus.ready => tryClientFromCachedBundle(),
      DriveCredentialStatus.revoked =>
        throw const GoogleDriveGrantRevokedException(),
      DriveCredentialStatus.unavailable => null,
    };
  }

  /// Returns an [http.Client] authorized for Drive scopes.
  ///
  /// Headless-only: uses cached OAuth tokens, PKCE refresh, or silent SDK
  /// restoration. Interactive sign-in is exclusively via [signIn] from
  /// user-initiated flows. The returned client self-heals on 401.
  Future<http.Client> getAuthenticatedHttpClient({
    bool headless = true,
  }) async {
    assert(headless, 'Interactive auth must use signIn() directly.');

    final bundleClient = await tryClientFromBundleOrRefresh();
    if (bundleClient != null) {
      return bundleClient;
    }

    await ensureInitialized();
    final bundle = await _authSessionStore.read();
    final scopes = bundle?.scopesGranted ?? _activeScopes;

    var account = _cachedAccount;
    account ??= await signInSilently();

    if (account != null) {
      if (bundle != null && account.id != bundle.googleUserId) {
        throw const GoogleAuthNotSignedInException(
          'Google account does not match the stored session bundle.',
        );
      }

      await _cacheAccessTokenFromAccount(account, scopes);
      final refreshed = await _authSessionStore.read();
      if (refreshed != null && refreshed.hasValidCachedAccessToken) {
        return _refreshingClient();
      }
    }

    throw const GoogleAuthNotSignedInException(
      'Google Drive is not authorized for this account. Sign in again to '
      'use Drive backup.',
    );
  }

  http.Client _refreshingClient() => DriveRefreshingHttpClient(
        getAccessToken: _currentAccessToken,
        forceRefresh: _forceRefreshAccessToken,
      );

  Future<String?> _currentAccessToken() async {
    final bundle = await _authSessionStore.read();
    if (bundle == null) {
      return null;
    }
    if (bundle.hasValidCachedAccessToken) {
      return bundle.cachedAccessToken;
    }
    final status = await ensureDriveCredential();
    if (status == DriveCredentialStatus.revoked) {
      throw const GoogleDriveGrantRevokedException();
    }
    if (status == DriveCredentialStatus.ready) {
      return (await _authSessionStore.read())?.cachedAccessToken;
    }
    return bundle.cachedAccessToken;
  }

  Future<String?> _forceRefreshAccessToken() async {
    await _authSessionStore.clearCachedAccessToken();
    final status = await ensureDriveCredential();
    switch (status) {
      case DriveCredentialStatus.ready:
        return (await _authSessionStore.read())?.cachedAccessToken;
      case DriveCredentialStatus.revoked:
        throw const GoogleDriveGrantRevokedException();
      case DriveCredentialStatus.unavailable:
        return _recoverTokenFromSdk();
    }
  }

  Future<String?> _recoverTokenFromSdk() async {
    final account = _cachedAccount;
    if (account == null) {
      return null;
    }
    final bundle = await _authSessionStore.read();
    final scopes = bundle?.scopesGranted ?? _activeScopes;
    await _cacheAccessTokenFromAccount(account, scopes);
    final refreshed = await _authSessionStore.read();
    if (refreshed != null && refreshed.hasValidCachedAccessToken) {
      return refreshed.cachedAccessToken;
    }
    return null;
  }
}
