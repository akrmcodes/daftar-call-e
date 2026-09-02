import 'package:envied/envied.dart';

part 'env.g.dart';

/// Build-time environment configuration with obfuscated secrets.
///
/// Uses `envied` to read values from the `.env` file at the project
/// root during code generation. The `obfuscate: true` flag ensures
/// the raw key is never stored as a plaintext string literal in the
/// compiled binary — instead, it is reconstructed at runtime via
/// XOR bit-shifting.
///
/// ## Regeneration
///
/// After changing `.env`, regenerate with:
/// ```sh
/// dart run build_runner build --delete-conflicting-outputs
/// ```
///
/// ## Security Notes
///
/// - The `.env` file is excluded from VCS by `.gitignore`.
/// - Obfuscation is NOT encryption — a determined attacker with the
///   APK can still reverse-engineer the key. This is a defence-in-depth
///   measure, not a cryptographic guarantee. The primary threat model
///   is casual inspection of the binary, not nation-state adversaries.
/// - The key MUST be backed up in a secure vault. If lost, all V1
///   backups become unrecoverable.
@Envied(path: '.env')
abstract class Env {
  /// AES-256 backup encryption key (Base64-encoded, 32 bytes decoded).
  ///
  /// Used by `EncryptionUtil` to encrypt/decrypt `.daftar` backup files.
  /// The value is obfuscated in the compiled binary via `envied`'s
  /// XOR bit-shifting — no plaintext key in the APK/IPA.
  @EnviedField(varName: 'BACKUP_AES_KEY', obfuscate: true)
  static String backupAesKey = _Env.backupAesKey;

  /// Google OAuth 2.0 Web Client ID (serverClientId).
  ///
  /// Required by `google_sign_in` v7 on Android when requesting
  /// additional OAuth scopes (e.g. `drive.appdata`). This MUST be a
  /// **"Web application"** type OAuth Client ID from Google Cloud
  /// Console — **NOT** the Android Client ID.
  ///
  /// See: Google Cloud Console → APIs & Services → Credentials →
  /// Create OAuth Client ID → Application type: Web application.
  @EnviedField(varName: 'GOOGLE_SERVER_CLIENT_ID', obfuscate: true)
  static String googleServerClientId = _Env.googleServerClientId;

  /// Google OAuth 2.0 **Android** client ID for the AppAuth PKCE offline
  /// grant (RFC 8252 native-app flow). Android-type installed clients have
  /// NO client secret — the refresh token is issued directly to the device.
  @EnviedField(
    varName: 'GOOGLE_OAUTH_CLIENT_ID_ANDROID',
    obfuscate: true,
    defaultValue: '',
  )
  static String googleOauthClientIdAndroid = _Env.googleOauthClientIdAndroid;

  /// Google OAuth 2.0 **iOS** client ID (same as `GIDClientID` in
  /// `Info.plist`) for the AppAuth PKCE offline grant.
  @EnviedField(
    varName: 'GOOGLE_OAUTH_CLIENT_ID_IOS',
    obfuscate: true,
    defaultValue: '',
  )
  static String googleOauthClientIdIos = _Env.googleOauthClientIdIos;

  /// Supabase Edge Functions base URL for premium activation (`/activate`).
  ///
  /// Example: `https://<project-ref>.supabase.co/functions/v1`
  @EnviedField(
    varName: 'ACTIVATION_API_BASE_URL',
    obfuscate: true,
    defaultValue: 'https://placeholder.supabase.co/functions/v1',
  )
  static String activationApiBaseUrl = _Env.activationApiBaseUrl;

  /// Supabase publishable API key (client-safe with RLS).
  ///
  /// Sent as the `apikey` header when calling Edge Functions such as
  /// `verify-google-token`. Required by `withSupabase({ auth: ["publishable"] })`.
  @EnviedField(
    varName: 'SUPABASE_PUBLISHABLE_KEY',
    obfuscate: true,
    defaultValue: '',
  )
  static String supabasePublishableKey = _Env.supabasePublishableKey;

  /// HTTPS base for minted deep-link URLs (no trailing slash on token).
  ///
  /// Example: `https://daftar.app/i` → invite URL `https://daftar.app/i/<token>`.
  /// Must match Android App Links host + iOS Associated Domains.
  @EnviedField(
    varName: 'DEEP_LINK_BASE_URL',
    obfuscate: true,
    defaultValue: 'https://daftar.app/i',
  )
  static String deepLinkBaseUrl = _Env.deepLinkBaseUrl;

  /// Authenticated Cloud Run base URL for the CALL-E agent (`daftar-call-e`).
  ///
  /// Contest `.env` only (gitignored). Public hostname, not a secret —
  /// Gemini/Vertex keys must never appear here.
  ///
  /// Empty default: a missing `.env` must not fall back to the frozen
  /// All Things Agentic Cloud Run host. Set `CLOSING_AGENT_BASE_URL` to the
  /// `daftar-call-e` URL from `$HOME/.daftar-owner-ops/daftar-call-e-url`.
  /// See `.cursor/rules/calle-agentic-freeze.mdc`.
  @EnviedField(
    varName: 'CLOSING_AGENT_BASE_URL',
    obfuscate: true,
    defaultValue: '',
  )
  static String closingAgentBaseUrl = _Env.closingAgentBaseUrl;
}
