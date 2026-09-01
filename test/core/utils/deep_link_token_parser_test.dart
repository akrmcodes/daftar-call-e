import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:daftar/data/datasources/remote/deep_link_remote_ds.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claimed_by.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_resolve_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLinkTokenParser', () {
    test('extracts token from daftar.app /i/ path', () {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';
      final uri = Uri.parse('https://daftar.app/i/$token');
      expect(DeepLinkTokenParser.extractToken(uri), token);
    });

    test('rejects short tokens', () {
      final uri = Uri.parse('https://daftar.app/i/short');
      expect(DeepLinkTokenParser.extractToken(uri), isNull);
    });

    test('extractFromRaw accepts bare token', () {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';
      expect(DeepLinkTokenParser.extractFromRaw(token), token);
    });
  });

  group('DeepLinkRemoteDs.mapClaimResponse', () {
    test('maps ok with worker invite intent', () {
      final result = DeepLinkRemoteDs.mapClaimResponse({
        'status': 'ok',
        'kind': 'worker_invite',
        'intent': {
          'member_id': 'm1',
          'invited_email': 'a@b.com',
          'role': 'editor',
          'workspace_id': 'ws-1',
        },
      });
      expect(result, isA<DeepLinkClaimOk>());
      final ok = result as DeepLinkClaimOk;
      expect(ok.intent.kind, DeepLinkTokenKind.workerInvite);
      expect(ok.intent.memberId, 'm1');
      expect(ok.intent.workspaceId, 'ws-1');
    });

    test('maps expired', () {
      expect(
        DeepLinkRemoteDs.mapClaimResponse({'status': 'expired'}),
        isA<DeepLinkClaimExpired>(),
      );
    });

    test('maps already_claimed by_you', () {
      final result = DeepLinkRemoteDs.mapClaimResponse({
        'status': 'already_claimed',
        'claimed_by': 'by_you',
      });
      expect(result, isA<DeepLinkClaimAlreadyClaimed>());
      expect(
        (result as DeepLinkClaimAlreadyClaimed).claimedBy,
        DeepLinkClaimedBy.byYou,
      );
    });

    test('anonymous not_found stays not_found when authenticated shape', () {
      expect(
        DeepLinkRemoteDs.mapClaimResponse({'status': 'not_found'}),
        isA<DeepLinkClaimNotFound>(),
      );
    });
  });

  group('DeepLinkRemoteDs.mapResolveResponse', () {
    test('maps active worker invite intent', () {
      final result = DeepLinkRemoteDs.mapResolveResponse({
        'status': 'active',
        'kind': 'worker_invite',
        'intent': {
          'member_id': 'm1',
          'invited_email': 'a@b.com',
          'role': 'editor',
          'workspace_id': 'ws-1',
        },
      });
      expect(result, isA<DeepLinkResolveActive>());
      final active = result as DeepLinkResolveActive;
      expect(active.intent.kind, DeepLinkTokenKind.workerInvite);
      expect(active.intent.workspaceId, 'ws-1');
    });

    test('maps expired', () {
      expect(
        DeepLinkRemoteDs.mapResolveResponse({'status': 'expired'}),
        isA<DeepLinkResolveExpired>(),
      );
    });
  });
}
