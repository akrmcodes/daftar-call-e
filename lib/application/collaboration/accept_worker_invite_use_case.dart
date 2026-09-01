import 'package:daftar/application/auth/exchange_sync_token_use_case.dart';
import 'package:daftar/application/deep_link/claim_deep_link_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/pending_worker_invite_store.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Parameters for accepting a worker invite (Stage 8.6).
class AcceptWorkerInviteParams {
  /// Creates params.
  const AcceptWorkerInviteParams({
    required this.token,
    required this.invitedEmail,
    this.role,
    this.workspaceId,
  });

  /// Opaque deep-link token.
  final String token;

  /// Email the owner invited.
  final String invitedEmail;

  /// Assigned workspace role when known from resolve preview.
  final WorkspaceRole? role;

  /// Merchant workspace id when known from resolve preview.
  final String? workspaceId;
}

/// Successful worker invite acceptance.
class AcceptWorkerInviteResult {
  /// Creates the result.
  const AcceptWorkerInviteResult({
    required this.workspaceId,
    required this.role,
    required this.googleEmail,
  });

  /// Joined workspace id from the refreshed sync JWT.
  final String workspaceId;

  /// Assigned role in the merchant workspace.
  final WorkspaceRole role;

  /// Google account email used for acceptance.
  final String googleEmail;
}

/// Orchestrates Google Sign-In → email match → claim → JWT refresh (§8.6).
class AcceptWorkerInviteUseCase {
  /// Creates the use case.
  const AcceptWorkerInviteUseCase({
    required AuthRepository authRepository,
    required ExchangeSyncTokenUseCase exchangeSyncTokenUseCase,
    required ClaimDeepLinkUseCase claimDeepLinkUseCase,
    required PendingWorkerInviteStore pendingInviteStore,
  })  : _authRepository = authRepository,
        _exchangeSyncToken = exchangeSyncTokenUseCase,
        _claimDeepLink = claimDeepLinkUseCase,
        _pendingInviteStore = pendingInviteStore;

  final AuthRepository _authRepository;
  final ExchangeSyncTokenUseCase _exchangeSyncToken;
  final ClaimDeepLinkUseCase _claimDeepLink;
  final PendingWorkerInviteStore _pendingInviteStore;

  /// Accepts a worker invite for [params].
  Future<Either<Failure, AcceptWorkerInviteResult>> call(
    AcceptWorkerInviteParams params,
  ) async {
    await _pendingInviteStore.save(params.token);

    final session = await _authRepository.getSessionState();
    if (session == AuthSessionState.unlinked) {
      final signIn = await _authRepository.signInWithGoogle();
      final signInFailure = signIn.fold((f) => f, (_) => null);
      if (signInFailure != null) {
        return Left(signInFailure);
      }
    }

    final profileResult = await _authRepository.getGoogleAccountProfile();
    return profileResult.fold(
      Left.new,
      (profile) async {
        final googleEmail = profile?.email.trim().toLowerCase() ?? '';
        final invited = params.invitedEmail.trim().toLowerCase();
        if (googleEmail.isEmpty || googleEmail != invited) {
          return const Left(
            AuthFailure(
              'Sign in with the Google account that received the invite.',
              code: 'invite_email_mismatch',
            ),
          );
        }

        final firstExchange = await _exchangeSyncToken.exchange(
          allowInteractive: true,
        );
        final exchangeFailure = firstExchange.fold((f) => f, (_) => null);
        if (exchangeFailure != null) {
          return Left(exchangeFailure);
        }

        final claimResult = await _claimDeepLink(
          params.token,
          googleEmail: googleEmail,
        );
        return claimResult.fold(
          Left.new,
          (claim) async {
            if (claim is! DeepLinkClaimOk) {
              return const Left(
                AuthFailure(
                  'Invite could not be claimed.',
                  code: 'invite_claim_failed',
                ),
              );
            }

            final refresh = await _exchangeSyncToken.exchange(
              allowInteractive: true,
            );
            return refresh.fold(
              Left.new,
              (credentials) async {
                await _pendingInviteStore.clear();
                final role = WorkspaceRole.fromString(credentials.role) ??
                    params.role ??
                    WorkspaceRole.viewer;
                return Right(
                  AcceptWorkerInviteResult(
                    workspaceId: credentials.workspaceId,
                    role: role,
                    googleEmail: googleEmail,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
