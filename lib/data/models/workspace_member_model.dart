import 'package:daftar/domain/entities/workspace_member.dart';
import 'package:daftar/domain/enums/member_status.dart';
import 'package:daftar/domain/enums/workspace_role.dart';

/// Data-layer model for a workspace_members PostgREST row.
class WorkspaceMemberModel {
  const WorkspaceMemberModel({
    required this.id,
    required this.invitedEmail,
    required this.role,
    required this.status,
    required this.seatIndex,
    required this.createdAt,
  });

  factory WorkspaceMemberModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceMemberModel(
      id: json['id'] as String,
      invitedEmail: json['invited_email'] as String?,
      role: WorkspaceRole.fromString(json['role'] as String?) ??
          WorkspaceRole.viewer,
      status: MemberStatus.fromString(json['status'] as String?) ??
          MemberStatus.pending,
      seatIndex: json['seat_index'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }

  final String id;
  final String? invitedEmail;
  final WorkspaceRole role;
  final MemberStatus status;
  final int seatIndex;
  final DateTime createdAt;

  WorkspaceMember toDomain() {
    return WorkspaceMember(
      id: id,
      invitedEmail: invitedEmail,
      role: role,
      status: status,
      seatIndex: seatIndex,
      createdAt: createdAt,
    );
  }
}
