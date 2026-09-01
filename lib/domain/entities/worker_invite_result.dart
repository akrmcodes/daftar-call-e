import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'worker_invite_result.freezed.dart';

/// Result of a successful worker invite from the Edge Function.
///
/// The workspace allows at most two concurrent editors *including the
/// owner*, so only one worker can hold an editor seat. An `editor` invite
/// beyond that is minted as a viewer instead. [role] is always the
/// effective role; [roleDowngraded] is the server's own statement that it
/// granted less than [requestedRole], which the client must never infer.
@freezed
abstract class WorkerInviteResult with _$WorkerInviteResult {
  const factory WorkerInviteResult({
    required String memberId,
    required String inviteUrl,
    required WorkspaceRole role,
    required DateTime expiresAt,
    required WorkspaceRole requestedRole,
    @Default(false) bool roleDowngraded,
  }) = _WorkerInviteResult;
}
