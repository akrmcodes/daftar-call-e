import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/permissions/permission_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionMatrix', () {
    test('null role denies all write permissions', () {
      expect(
        PermissionMatrix.allows(null, WorkspacePermission.editTransactions),
        isFalse,
      );
      expect(
        PermissionMatrix.allows(null, WorkspacePermission.editContactsAndLedgers),
        isFalse,
      );
      expect(
        PermissionMatrix.allows(null, WorkspacePermission.inviteWorkers),
        isFalse,
      );
    });

    test('viewer cannot edit transactions or contacts', () {
      expect(
        PermissionMatrix.allows(
          WorkspaceRole.viewer,
          WorkspacePermission.editTransactions,
        ),
        isFalse,
      );
      expect(
        PermissionMatrix.allows(
          WorkspaceRole.viewer,
          WorkspacePermission.editContactsAndLedgers,
        ),
        isFalse,
      );
      expect(
        PermissionMatrix.allows(
          WorkspaceRole.viewer,
          WorkspacePermission.inviteWorkers,
        ),
        isFalse,
      );
    });

    test('viewer can view ledgers', () {
      expect(
        PermissionMatrix.allows(
          WorkspaceRole.viewer,
          WorkspacePermission.viewLedgers,
        ),
        isTrue,
      );
    });

    test('editor can edit transactions but cannot invite workers', () {
      expect(
        PermissionMatrix.allows(
          WorkspaceRole.editor,
          WorkspacePermission.editTransactions,
        ),
        isTrue,
      );
      expect(
        PermissionMatrix.allows(
          WorkspaceRole.editor,
          WorkspacePermission.inviteWorkers,
        ),
        isFalse,
      );
    });

    test('owner can invite workers', () {
      expect(
        PermissionMatrix.allows(
          WorkspaceRole.owner,
          WorkspacePermission.inviteWorkers,
        ),
        isTrue,
      );
    });
  });
}
