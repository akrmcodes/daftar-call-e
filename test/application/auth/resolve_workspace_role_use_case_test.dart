import 'package:daftar/application/auth/resolve_workspace_role_use_case.dart';
import 'package:daftar/domain/entities/workspace_membership_snapshot.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncAuthBridgeRepository extends Mock
    implements SyncAuthBridgeRepository {}

void main() {
  late MockSyncAuthBridgeRepository syncBridge;
  late ResolveWorkspaceRoleUseCase sut;

  setUp(() {
    syncBridge = MockSyncAuthBridgeRepository();
    sut = ResolveWorkspaceRoleUseCase(
      syncAuthBridgeRepository: syncBridge,
    );
  });

  test('no membership snapshot defaults to owner (solo / pre-sync Pro+)', () async {
    when(() => syncBridge.readLastKnownMembership())
        .thenAnswer((_) async => null);

    expect(await sut(), WorkspaceRole.owner);
  });

  test('worker JWT returns editor', () async {
    when(() => syncBridge.readLastKnownMembership()).thenAnswer(
      (_) async => const WorkspaceMembershipSnapshot(
        workspaceId: 'ws-1',
        role: 'editor',
      ),
    );

    expect(await sut(), WorkspaceRole.editor);
  });

  test('owner JWT returns owner', () async {
    when(() => syncBridge.readLastKnownMembership()).thenAnswer(
      (_) async => const WorkspaceMembershipSnapshot(
        workspaceId: 'ws-1',
        role: 'owner',
      ),
    );

    expect(await sut(), WorkspaceRole.owner);
  });

  test('viewer JWT is not escalated to owner', () async {
    when(() => syncBridge.readLastKnownMembership()).thenAnswer(
      (_) async => const WorkspaceMembershipSnapshot(
        workspaceId: 'ws-1',
        role: 'viewer',
      ),
    );

    expect(await sut(), WorkspaceRole.viewer);
  });
}
