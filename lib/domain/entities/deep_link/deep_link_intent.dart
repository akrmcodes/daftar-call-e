import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'deep_link_intent.freezed.dart';

/// Routing intent returned on a successful deep-link claim.
@freezed
abstract class DeepLinkIntent with _$DeepLinkIntent {
  const factory DeepLinkIntent({
    required DeepLinkTokenKind kind,
    String? workspaceId,
    String? memberId,
    String? contactId,
    String? referrerId,
    String? invitedEmail,
    WorkspaceRole? role,
  }) = _DeepLinkIntent;
}
