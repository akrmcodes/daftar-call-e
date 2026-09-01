import 'package:daftar/application/deep_link/claim_deep_link_use_case.dart';
import 'package:daftar/application/deep_link/create_deep_link_use_case.dart';
import 'package:daftar/application/deep_link/request_new_invite_use_case.dart';
import 'package:daftar/application/deep_link/resolve_deep_link_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeepLinkRepository extends Mock implements DeepLinkRepository {}

void main() {
  late MockDeepLinkRepository repository;

  const token = 'abcdefghijklmnopqrstuvwxyz012345';

  setUpAll(() {
    registerFallbackValue(DeepLinkTokenKind.share);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = MockDeepLinkRepository();
  });

  final contestFailure = isA<AuthFailure>().having(
    (f) => f.code,
    'code',
    'contest_sync_quarantined',
  );

  group('deep-link use cases contest quarantine', () {
    test('kill-switch is on for this build', () {
      expect(AppConstants.kContestDisableMultiDeviceSync, isTrue);
    });

    test('ClaimDeepLinkUseCase never calls the repository', () async {
      final result = await ClaimDeepLinkUseCase(
        deepLinkRepository: repository,
      ).call(token, googleEmail: 'worker@example.com');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, contestFailure),
        (_) => fail('expected contest quarantine failure'),
      );
      verifyNever(
        () => repository.claimToken(
          any(),
          googleEmail: any(named: 'googleEmail'),
        ),
      );
    });

    test('CreateDeepLinkUseCase never calls the repository', () async {
      final result = await CreateDeepLinkUseCase(
        deepLinkRepository: repository,
      ).call(
        kind: DeepLinkTokenKind.share,
        intentPayload: const {'ledgerId': 'ledger-1'},
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, contestFailure),
        (_) => fail('expected contest quarantine failure'),
      );
      verifyNever(
        () => repository.createDeepLink(
          kind: any(named: 'kind'),
          intentPayload: any(named: 'intentPayload'),
        ),
      );
    });

    test('ResolveDeepLinkUseCase never calls the repository', () async {
      final result = await ResolveDeepLinkUseCase(
        deepLinkRepository: repository,
      ).call(token);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, contestFailure),
        (_) => fail('expected contest quarantine failure'),
      );
      verifyNever(() => repository.resolveToken(any()));
    });

    test('RequestNewInviteUseCase never calls the repository', () async {
      final result = await RequestNewInviteUseCase(
        deepLinkRepository: repository,
      ).call(token);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, contestFailure),
        (_) => fail('expected contest quarantine failure'),
      );
      verifyNever(() => repository.requestNewInvite(any()));
    });
  });
}
