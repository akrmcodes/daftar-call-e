/// Workspace collaboration role (Pro+ multi-worker).
enum WorkspaceRole {
  owner,
  editor,
  viewer;

  /// Parses a role string from the sync JWT or API response.
  static WorkspaceRole? fromString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return switch (value.toLowerCase()) {
      'owner' => WorkspaceRole.owner,
      'editor' => WorkspaceRole.editor,
      'viewer' => WorkspaceRole.viewer,
      _ => null,
    };
  }
}
