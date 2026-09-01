import 'package:daftar/domain/enums/member_status.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_member.freezed.dart';

/// A workspace member or pending invite (Stage 8.5).
@freezed
abstract class WorkspaceMember with _$WorkspaceMember {
  const factory WorkspaceMember({
    required String id,
    required String? invitedEmail,
    required WorkspaceRole role,
    required MemberStatus status,
    required int seatIndex,
    required DateTime createdAt,
  }) = _WorkspaceMember;

  const WorkspaceMember._();

  bool get isOwner => role == WorkspaceRole.owner;

  bool get isPending => status == MemberStatus.pending;

  bool get isActive => status == MemberStatus.active;
}
