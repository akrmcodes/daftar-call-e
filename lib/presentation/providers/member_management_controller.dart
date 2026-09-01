import 'package:daftar/domain/entities/invite_renewal_request.dart';
import 'package:daftar/domain/entities/worker_invite_result.dart';
import 'package:daftar/domain/entities/workspace_member.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/presentation/providers/collaboration_providers.dart';
import 'package:daftar/presentation/providers/permissions_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'member_management_controller.g.dart';

@riverpod
Future<List<WorkspaceMember>> workspaceMembers(Ref ref) async {
  final role = await ref.watch(currentWorkspaceRoleProvider.future);
  final useCase = ref.watch(listWorkspaceMembersUseCaseProvider);
  final result = await useCase.execute(currentRole: role);
  return result.fold(
    (_) => const [],
    (members) => members,
  );
}

@riverpod
Future<List<InviteRenewalRequest>> inviteRenewalRequests(Ref ref) async {
  final role = await ref.watch(currentWorkspaceRoleProvider.future);
  final result = await ref
      .read(listInviteRenewalRequestsUseCaseProvider)
      .execute(currentRole: role);
  return result.fold(
    (_) => const [],
    (requests) => requests,
  );
}

@Riverpod(keepAlive: true)
class MemberManagementController extends _$MemberManagementController {
  @override
  FutureOr<void> build() {}

  Future<WorkerInviteResult?> inviteWorker({
    required String email,
    required WorkspaceRole role,
  }) async {
    state = const AsyncLoading();
    final currentRole = await ref.read(currentWorkspaceRoleProvider.future);
    final result = await ref.read(inviteWorkerUseCaseProvider).execute(
          currentRole: currentRole,
          inviteeEmail: email,
          inviteRole: role,
        );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (invite) {
        state = const AsyncData(null);
        ref.invalidate(workspaceMembersProvider);
        return invite;
      },
    );
  }

  Future<bool> revokeInvite(String memberId) async {
    state = const AsyncLoading();
    final currentRole = await ref.read(currentWorkspaceRoleProvider.future);
    final result = await ref.read(revokeWorkerInviteUseCaseProvider).execute(
          currentRole: currentRole,
          memberId: memberId,
        );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(workspaceMembersProvider);
        return true;
      },
    );
  }

  Future<bool> removeMember({
    required String memberId,
    required int seatIndex,
  }) async {
    state = const AsyncLoading();
    final currentRole = await ref.read(currentWorkspaceRoleProvider.future);
    final result = await ref.read(removeWorkspaceMemberUseCaseProvider).execute(
          currentRole: currentRole,
          memberId: memberId,
          seatIndex: seatIndex,
        );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(workspaceMembersProvider);
        return true;
      },
    );
  }

  Future<bool> fulfillRenewalRequest(String renewalId) async {
    state = const AsyncLoading();
    final currentRole = await ref.read(currentWorkspaceRoleProvider.future);
    final result = await ref
        .read(fulfillInviteRenewalRequestUseCaseProvider)
        .execute(
          currentRole: currentRole,
          renewalId: renewalId,
        );
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(inviteRenewalRequestsProvider);
        return true;
      },
    );
  }

  /// Clears a surfaced [AsyncError] so error sheets are not shown again on rebuild.
  void clearError() {
    if (state.hasError) {
      state = const AsyncData(null);
    }
  }
}
