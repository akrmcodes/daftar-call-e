import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:daftar/app/router/app_router_provider.dart';
import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/application/deep_link/claim_deep_link_use_case.dart';
import 'package:daftar/application/deep_link/create_deep_link_use_case.dart';
import 'package:daftar/application/deep_link/request_new_invite_use_case.dart';
import 'package:daftar/application/deep_link/resolve_deep_link_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/consumed_initial_link_store.dart';
import 'package:daftar/core/services/handled_deep_link_store.dart';
import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:daftar/data/datasources/remote/deep_link_remote_ds.dart';
import 'package:daftar/data/repositories/deep_link_repository_impl.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_intent.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_resolve_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deep_link_providers.g.dart';

/// Remote deep-link transport.
@Riverpod(keepAlive: true)
DeepLinkRemoteDs deepLinkRemoteDs(Ref ref) {
  return DeepLinkRemoteDs(
    dio: ref.watch(dioClientProvider),
    syncTokenStore: ref.watch(syncTokenStoreProvider),
  );
}

/// Deep-link repository.
@Riverpod(keepAlive: true)
DeepLinkRepository deepLinkRepository(Ref ref) {
  return DeepLinkRepositoryImpl(
    remoteDs: ref.watch(deepLinkRemoteDsProvider),
  );
}

@Riverpod(keepAlive: true)
ResolveDeepLinkUseCase resolveDeepLinkUseCase(Ref ref) {
  return ResolveDeepLinkUseCase(
    deepLinkRepository: ref.watch(deepLinkRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
ClaimDeepLinkUseCase claimDeepLinkUseCase(Ref ref) {
  return ClaimDeepLinkUseCase(
    deepLinkRepository: ref.watch(deepLinkRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
RequestNewInviteUseCase requestNewInviteUseCase(Ref ref) {
  return RequestNewInviteUseCase(
    deepLinkRepository: ref.watch(deepLinkRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
HandledDeepLinkStore handledDeepLinkStore(Ref ref) {
  return HandledDeepLinkStore();
}

@Riverpod(keepAlive: true)
ConsumedInitialLinkStore consumedInitialLinkStore(Ref ref) {
  return ConsumedInitialLinkStore();
}

@Riverpod(keepAlive: true)
CreateDeepLinkUseCase createDeepLinkUseCase(Ref ref) {
  return CreateDeepLinkUseCase(
    deepLinkRepository: ref.watch(deepLinkRepositoryProvider),
  );
}

/// Result of handling one deep-link token.
///
/// Cold-start and OS-stream links route themselves, but manual code entry
/// needs to know whether anything happened so it can tell the user.
sealed class DeepLinkHandleOutcome {
  const DeepLinkHandleOutcome();

  /// The token resolved and navigation has been performed.
  const factory DeepLinkHandleOutcome.routed() = DeepLinkHandleRouted;

  /// The string carried no usable token.
  const factory DeepLinkHandleOutcome.invalidToken() =
      DeepLinkHandleInvalidToken;

  /// This token was already consumed on this device.
  const factory DeepLinkHandleOutcome.alreadyHandled() =
      DeepLinkHandleAlreadyHandled;

  /// Another token is mid-flight; the caller should retry.
  const factory DeepLinkHandleOutcome.busy() = DeepLinkHandleBusy;

  /// Resolve or claim failed — surface [failure] through `ErrorTranslator`.
  const factory DeepLinkHandleOutcome.failed(Failure failure) =
      DeepLinkHandleFailed;
}

/// See [DeepLinkHandleOutcome.routed].
final class DeepLinkHandleRouted extends DeepLinkHandleOutcome {
  /// Creates the outcome.
  const DeepLinkHandleRouted();
}

/// See [DeepLinkHandleOutcome.invalidToken].
final class DeepLinkHandleInvalidToken extends DeepLinkHandleOutcome {
  /// Creates the outcome.
  const DeepLinkHandleInvalidToken();
}

/// See [DeepLinkHandleOutcome.alreadyHandled].
final class DeepLinkHandleAlreadyHandled extends DeepLinkHandleOutcome {
  /// Creates the outcome.
  const DeepLinkHandleAlreadyHandled();
}

/// See [DeepLinkHandleOutcome.busy].
final class DeepLinkHandleBusy extends DeepLinkHandleOutcome {
  /// Creates the outcome.
  const DeepLinkHandleBusy();
}

/// See [DeepLinkHandleOutcome.failed].
final class DeepLinkHandleFailed extends DeepLinkHandleOutcome {
  /// Creates the outcome.
  const DeepLinkHandleFailed(this.failure);

  /// The underlying failure.
  final Failure failure;
}

/// OS App/Universal Link listener → resolve/claim → go_router navigation.
@Riverpod(keepAlive: true)
class DeepLinkController extends _$DeepLinkController {
  StreamSubscription<Uri>? _sub;
  final AppLinks _appLinks = AppLinks();
  bool _handling = false;
  String? _initialLinkToken;

  /// True when [token] was consumed from cold-start `getInitialLink()`.
  bool wasInitialLinkToken(String token) {
    final normalized = token.trim();
    return normalized.isNotEmpty && normalized == _initialLinkToken;
  }

  HandledDeepLinkStore get _handledStore =>
      ref.read(handledDeepLinkStoreProvider);

  ConsumedInitialLinkStore get _consumedInitialStore =>
      ref.read(consumedInitialLinkStoreProvider);

  @override
  Future<void> build() async {
    ref.onDispose(() {
      unawaited(_sub?.cancel());
    });

    // Contest quarantine — Stage 8 disabled (no AppLinks / resolve / claim).
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return;
    }

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _initialLinkToken = DeepLinkTokenParser.extractToken(initial);
        if (await _consumedInitialStore.isConsumed(
          uri: initial,
          token: _initialLinkToken,
        )) {
          debugPrint('DeepLink skip consumed initial link');
        } else {
          await handleUri(initial);
          await _consumedInitialStore.markConsumed(
            uri: initial,
            token: _initialLinkToken,
          );
        }
      }
    } on Object catch (e, st) {
      debugPrint('DeepLinkController initial link failed: $e\n$st');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(handleUri(uri)),
      onError: (Object e, StackTrace st) {
        debugPrint('DeepLinkController stream error: $e\n$st');
      },
    );
  }

  /// Handles a deep-link [uri] or bare token string from manual entry.
  Future<DeepLinkHandleOutcome> handleUri(Uri uri) async {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return const DeepLinkHandleOutcome.invalidToken();
    }
    final token = DeepLinkTokenParser.extractToken(uri);
    if (token == null) {
      return const DeepLinkHandleOutcome.invalidToken();
    }
    return handleToken(token);
  }

  /// Resolves or claims [token] and routes by result type.
  ///
  /// Returns the outcome so manual-entry callers can render a localized
  /// message instead of leaving the user staring at an inert button.
  Future<DeepLinkHandleOutcome> handleToken(String token) async {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return const DeepLinkHandleOutcome.invalidToken();
    }
    if (_handling) {
      return const DeepLinkHandleOutcome.busy();
    }
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return const DeepLinkHandleOutcome.invalidToken();
    }
    if (await _handledStore.isHandled(normalized)) {
      debugPrint('DeepLink skip handled token: ${_tokenPreview(normalized)}');
      return const DeepLinkHandleOutcome.alreadyHandled();
    }
    _handling = true;
    try {
      final resolveResult =
          await ref.read(resolveDeepLinkUseCaseProvider).call(normalized);
      if (!ref.mounted) {
        return const DeepLinkHandleOutcome.busy();
      }

      return await resolveResult.fold(
        (failure) async {
          _logFailure('resolve', failure);
          return DeepLinkHandleOutcome.failed(failure);
        },
        (resolved) async {
          if (resolved is DeepLinkResolveActive &&
              resolved.intent.kind == DeepLinkTokenKind.workerInvite) {
            await _routeWorkerInviteAccept(normalized, resolved.intent);
            return const DeepLinkHandleOutcome.routed();
          }

          if (resolved is DeepLinkResolveActive) {
            return _claimAndRouteShareReferral(normalized);
          }

          await _routeResolveTerminal(normalized, resolved);
          return const DeepLinkHandleOutcome.routed();
        },
      );
    } finally {
      _handling = false;
    }
  }

  /// Truncation guard: hand-typed codes can be shorter than the preview.
  static String _tokenPreview(String token) {
    return token.length > 8 ? '${token.substring(0, 8)}…' : token;
  }

  void _logFailure(String stage, Failure failure) {
    debugPrint(
      'DeepLink $stage failure: code=${failure.code ?? 'none'} '
      'message=${failure.message}',
    );
  }

  Future<DeepLinkHandleOutcome> _claimAndRouteShareReferral(
    String token,
  ) async {
    final result = await ref.read(claimDeepLinkUseCaseProvider).call(token);
    if (!ref.mounted) {
      return const DeepLinkHandleOutcome.busy();
    }
    return result.fold(
      (failure) {
        _logFailure('claim', failure);
        return DeepLinkHandleOutcome.failed(failure);
      },
      (claim) async {
        await _routeClaimResult(token, claim);
        return const DeepLinkHandleOutcome.routed();
      },
    );
  }

  Future<void> _markTerminalHandled(String token) async {
    await _handledStore.markHandled(token);
  }

  Future<void> _routeWorkerInviteAccept(
    String token,
    DeepLinkIntent intent,
  ) async {
    final workspaceId = intent.workspaceId;
    final invitedEmail = intent.invitedEmail;
    final role = intent.role;

    ref.read(goRouterProvider).goNamed(
      RouteNames.inviteAccept,
      queryParameters: {
        'token': token,
        'workspaceId': ?workspaceId,
        'email': ?invitedEmail,
        'role': ?role?.name,
      },
    );
  }

  Future<void> _routeResolveTerminal(
    String token,
    DeepLinkResolveResult resolved,
  ) async {
    await _markTerminalHandled(token);
    final router = ref.read(goRouterProvider);
    switch (resolved) {
      case DeepLinkResolveExpired():
        router.goNamed(
          RouteNames.inviteCeremony,
          queryParameters: {'token': token, 'status': 'expired'},
        );
      case DeepLinkResolveRevoked():
      case DeepLinkResolveNotFound():
        router.goNamed(
          RouteNames.inviteCeremony,
          queryParameters: {'token': token, 'status': 'revoked'},
        );
      case DeepLinkResolveAlreadyClaimed(:final claimedBy):
        router.goNamed(
          RouteNames.inviteCeremony,
          queryParameters: {
            'token': token,
            'status': 'already_claimed',
            'claimedBy': claimedBy.toWire(),
          },
        );
      case DeepLinkResolveActive():
        break;
    }
  }

  Future<void> _routeClaimResult(
    String token,
    DeepLinkClaimResult claim,
  ) async {
    final router = ref.read(goRouterProvider);
    switch (claim) {
      case DeepLinkClaimOk(:final intent):
        switch (intent.kind) {
          case DeepLinkTokenKind.workerInvite:
            await _routeWorkerInviteAccept(token, intent);
          case DeepLinkTokenKind.share:
          case DeepLinkTokenKind.referral:
            router.goNamed(
              RouteNames.inviteAccept,
              queryParameters: {
                'token': token,
                'kind': intent.kind.toWire(),
              },
            );
        }
      case DeepLinkClaimExpired():
      case DeepLinkClaimRevoked():
      case DeepLinkClaimNotFound():
      case DeepLinkClaimAlreadyClaimed():
        await _markTerminalHandled(token);
        router.goNamed(
          RouteNames.inviteCeremony,
          queryParameters: {
            'token': token,
            'status': _statusWire(claim),
            if (claim is DeepLinkClaimAlreadyClaimed)
              'claimedBy': claim.claimedBy.toWire(),
          },
        );
    }
  }

  String _statusWire(DeepLinkClaimResult claim) {
    return switch (claim) {
      DeepLinkClaimExpired() => 'expired',
      DeepLinkClaimRevoked() => 'revoked',
      DeepLinkClaimNotFound() => 'revoked',
      DeepLinkClaimAlreadyClaimed() => 'already_claimed',
      DeepLinkClaimOk() => 'ok',
    };
  }
}
