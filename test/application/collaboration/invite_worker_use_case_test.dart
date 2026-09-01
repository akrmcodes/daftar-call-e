import 'package:daftar/application/collaboration/invite_worker_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/worker_invite_result.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/audit_log_repository.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkspaceMemberRepository extends Mock
    implements WorkspaceMemberRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

class MockAuditLogRepository extends Mock implements AuditLogRepository {}

void main() {
  late MockWorkspaceMemberRepository memberRepository;
  late MockActivationRepository activationRepository;
  late MockAuditLogRepository auditLogRepository;
  late InviteWorkerUseCase sut;

  final inviteResult = WorkerInviteResult(
    memberId: 'member-1',
    inviteUrl: 'https://daftar.app/i/token',
    role: WorkspaceRole.editor,
    expiresAt: DateTime.utc(2026, 7, 8),
    requestedRole: WorkspaceRole.editor,
  );

  setUpAll(() {
    registerFallbackValue(FeatureFlag.multiDeviceSync);
    registerFallbackValue(WorkspaceRole.viewer);
    registerFallbackValue(
      const AppendAuditLogParams(
        entityType: 'workspace_member',
        entityId: 'member-1',
        action: 'CREATE',
      ),
    );
  });

  setUp(() {
    memberRepository = MockWorkspaceMemberRepository();
    activationRepository = MockActivationRepository();
    auditLogRepository = MockAuditLogRepository();
    sut = InviteWorkerUseCase(
      memberRepository: memberRepository,
      activationRepository: activationRepository,
      auditLogRepository: auditLogRepository,
    );
  });

  group('InviteWorkerUseCase', () {
    test('editor role returns Left without calling repository', () async {
      when(
        () => activationRepository.isFeatureUnlocked(
          FeatureFlag.multiDeviceSync,
        ),
      ).thenAnswer((_) async => true);

      final result = await sut.execute(
        currentRole: WorkspaceRole.editor,
        inviteeEmail: 'worker@example.com',
        inviteRole: WorkspaceRole.viewer,
      );

      expect(result.isLeft(), isTrue);
      verifyZeroInteractions(memberRepository);
    });

    test('free tier without multiDeviceSync returns Left', () async {
      when(
        () => activationRepository.isFeatureUnlocked(
          FeatureFlag.multiDeviceSync,
        ),
      ).thenAnswer((_) async => false);

      final result = await sut.execute(
        currentRole: WorkspaceRole.owner,
        inviteeEmail: 'worker@example.com',
        inviteRole: WorkspaceRole.editor,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<LimitExceededFailure>()),
        (_) => fail('expected Left'),
      );
      verifyZeroInteractions(memberRepository);
    });

    test('owner with Pro+ calls repository and appends audit log', () async {
      when(
        () => activationRepository.isFeatureUnlocked(
          FeatureFlag.multiDeviceSync,
        ),
      ).thenAnswer((_) async => true);
      when(
        () => memberRepository.inviteWorker(
          inviteeEmail: 'worker@example.com',
          role: WorkspaceRole.editor,
        ),
      ).thenAnswer((_) async => Right(inviteResult));
      when(() => auditLogRepository.append(any())).thenAnswer(
        (_) async => const Right(unit),
      );

      final result = await sut.execute(
        currentRole: WorkspaceRole.owner,
        inviteeEmail: 'worker@example.com',
        inviteRole: WorkspaceRole.editor,
      );

      expect(result.isRight(), isTrue);
      verify(
        () => memberRepository.inviteWorker(
          inviteeEmail: 'worker@example.com',
          role: WorkspaceRole.editor,
        ),
      ).called(1);
      verify(() => auditLogRepository.append(any())).called(1);
    });
  });
}
