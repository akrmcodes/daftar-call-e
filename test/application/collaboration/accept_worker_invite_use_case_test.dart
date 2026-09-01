import 'package:daftar/application/auth/exchange_sync_token_use_case.dart';
import 'package:daftar/application/collaboration/accept_worker_invite_use_case.dart';
import 'package:daftar/application/deep_link/claim_deep_link_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/pending_worker_invite_store.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeepLinkRepository extends Mock implements DeepLinkRepository {}

class MockSyncAuthBridgeRepository extends Mock
    implements SyncAuthBridgeRepository {}

class MockPendingWorkerInviteStore extends Mock
    implements PendingWorkerInviteStore {}

void main() {
  late MockAuthRepository authRepository;
  late MockDeepLinkRepository deepLinkRepository;
  late MockSyncAuthBridgeRepository syncAuthBridge;
  late MockPendingWorkerInviteStore pendingStore;
  late AcceptWorkerInviteUseCase sut;

  const token = 'abcdefghijklmnopqrstuvwxyz012345';
  const invitedEmail = 'worker@example.com';

  setUp(() {
    authRepository = MockAuthRepository();
    deepLinkRepository = MockDeepLinkRepository();
    syncAuthBridge = MockSyncAuthBridgeRepository();
    pendingStore = MockPendingWorkerInviteStore();

    sut = AcceptWorkerInviteUseCase(
      authRepository: authRepository,
      exchangeSyncTokenUseCase: ExchangeSyncTokenUseCase(syncAuthBridge),
      claimDeepLinkUseCase: ClaimDeepLinkUseCase(
        deepLinkRepository: deepLinkRepository,
      ),
      pendingInviteStore: pendingStore,
    );

    when(() => pendingStore.save(any())).thenAnswer((_) async {});
    when(() => pendingStore.clear()).thenAnswer((_) async {});
    when(() => authRepository.getSessionState())
        .thenAnswer((_) async => AuthSessionState.linked);
    when(() => authRepository.getGoogleAccountProfile()).thenAnswer(
      (_) async => const Right(
        GoogleAccountProfile(id: 'g1', email: invitedEmail),
      ),
    );
  });

  test('rejects email mismatch before claim', () async {
    when(() => authRepository.getGoogleAccountProfile()).thenAnswer(
      (_) async => const Right(
        GoogleAccountProfile(id: 'g1', email: 'other@example.com'),
      ),
    );

    final result = await sut(
      const AcceptWorkerInviteParams(
        token: token,
        invitedEmail: invitedEmail,
      ),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure.code, 'invite_email_mismatch'),
      (_) => fail('expected failure'),
    );
    verifyNever(
      () => deepLinkRepository.claimToken(any(), googleEmail: any(named: 'googleEmail')),
    );
  });

  test('contest quarantine fails closed before claim or JWT exchange', () async {
    final result = await sut(
      const AcceptWorkerInviteParams(
        token: token,
        invitedEmail: invitedEmail,
        role: WorkspaceRole.editor,
      ),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.code, 'contest_sync_quarantined');
      },
      (_) => fail('expected contest quarantine failure'),
    );
    verifyNever(
      () => syncAuthBridge.exchange(
        allowInteractive: any(named: 'allowInteractive'),
      ),
    );
    verifyNever(
      () => deepLinkRepository.claimToken(
        any(),
        googleEmail: any(named: 'googleEmail'),
      ),
    );
    verifyNever(() => pendingStore.clear());
  });
}
