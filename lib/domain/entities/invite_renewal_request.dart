/// Pending worker renewal request from expired-link ceremony (Stage 8.5.1).
class InviteRenewalRequest {
  /// Creates a renewal request row for the merchant Team inbox.
  const InviteRenewalRequest({
    required this.id,
    required this.workspaceId,
    required this.originalToken,
    required this.invitedEmail,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String originalToken;
  final String invitedEmail;
  final DateTime createdAt;
}
