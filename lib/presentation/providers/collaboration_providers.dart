import 'package:daftar/application/collaboration/invite_worker_use_case.dart';
import 'package:daftar/application/collaboration/list_invite_renewal_requests_use_case.dart';
import 'package:daftar/application/collaboration/list_workspace_members_use_case.dart';
import 'package:daftar/application/collaboration/remove_workspace_member_use_case.dart';
import 'package:daftar/application/collaboration/revoke_worker_invite_use_case.dart';
import 'package:daftar/data/datasources/remote/workspace_member_remote_ds.dart';
import 'package:daftar/data/repositories/audit_log_repository_impl.dart';
import 'package:daftar/data/repositories/workspace_member_repository_impl.dart';
import 'package:daftar/domain/repositories/audit_log_repository.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'collaboration_providers.g.dart';

@Riverpod(keepAlive: true)
WorkspaceMemberRemoteDs workspaceMemberRemoteDs(Ref ref) {
  return WorkspaceMemberRemoteDs(
    dio: ref.watch(dioClientProvider),
    syncTokenStore: ref.watch(syncTokenStoreProvider),
  );
}

@Riverpod(keepAlive: true)
WorkspaceMemberRepository workspaceMemberRepository(Ref ref) {
  return WorkspaceMemberRepositoryImpl(
    remoteDs: ref.watch(workspaceMemberRemoteDsProvider),
  );
}

@Riverpod(keepAlive: true)
AuditLogRepository auditLogRepository(Ref ref) {
  return AuditLogRepositoryImpl(
    auditLogLocalDataSource: ref.watch(auditLogLocalDataSourceProvider),
  );
}

@Riverpod(keepAlive: true)
InviteWorkerUseCase inviteWorkerUseCase(Ref ref) {
  return InviteWorkerUseCase(
    memberRepository: ref.watch(workspaceMemberRepositoryProvider),
    activationRepository: ref.watch(activationRepositoryProvider),
    auditLogRepository: ref.watch(auditLogRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
ListWorkspaceMembersUseCase listWorkspaceMembersUseCase(Ref ref) {
  return ListWorkspaceMembersUseCase(
    memberRepository: ref.watch(workspaceMemberRepositoryProvider),
    activationRepository: ref.watch(activationRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
RevokeWorkerInviteUseCase revokeWorkerInviteUseCase(Ref ref) {
  return RevokeWorkerInviteUseCase(
    memberRepository: ref.watch(workspaceMemberRepositoryProvider),
    activationRepository: ref.watch(activationRepositoryProvider),
    auditLogRepository: ref.watch(auditLogRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
ListInviteRenewalRequestsUseCase listInviteRenewalRequestsUseCase(Ref ref) {
  return ListInviteRenewalRequestsUseCase(
    memberRepository: ref.watch(workspaceMemberRepositoryProvider),
    activationRepository: ref.watch(activationRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
FulfillInviteRenewalRequestUseCase fulfillInviteRenewalRequestUseCase(
  Ref ref,
) {
  return FulfillInviteRenewalRequestUseCase(
    memberRepository: ref.watch(workspaceMemberRepositoryProvider),
    activationRepository: ref.watch(activationRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
RemoveWorkspaceMemberUseCase removeWorkspaceMemberUseCase(Ref ref) {
  return RemoveWorkspaceMemberUseCase(
    memberRepository: ref.watch(workspaceMemberRepositoryProvider),
    activationRepository: ref.watch(activationRepositoryProvider),
    auditLogRepository: ref.watch(auditLogRepositoryProvider),
  );
}
