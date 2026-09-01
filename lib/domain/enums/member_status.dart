/// Workspace membership lifecycle state.
enum MemberStatus {
  pending,
  active;

  static MemberStatus? fromString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return switch (value.toLowerCase()) {
      'pending' => MemberStatus.pending,
      'active' => MemberStatus.active,
      _ => null,
    };
  }
}
