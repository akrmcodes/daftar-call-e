import 'package:daftar/application/merchant/clear_merchant_logo_use_case.dart';
import 'package:daftar/application/merchant/set_merchant_logo_use_case.dart';
import 'package:daftar/application/merchant/update_merchant_profile_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockMerchantProfileRepository extends Mock
    implements MerchantProfileRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  late MockMerchantProfileRepository merchantProfileRepository;
  late MockActivationRepository activationRepository;
  final now = DateTime.utc(2026, 6);

  MerchantProfile existingProfile() {
    return MerchantProfile(
      id: 'merchant-1',
      storeName: 'Store',
      createdAt: now,
      updatedAt: now,
    );
  }

  setUpAll(() {
    registerFallbackValue(FeatureFlag.brandedPdf);
    registerFallbackValue(existingProfile());
  });

  setUp(() {
    merchantProfileRepository = MockMerchantProfileRepository();
    activationRepository = MockActivationRepository();
  });

  group('UpdateMerchantProfileUseCase', () {
    late UpdateMerchantProfileUseCase sut;

    setUp(() {
      sut = UpdateMerchantProfileUseCase(merchantProfileRepository);
    });

    test('persists store name on the free tier', () async {
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => const Right(null),
      );
      when(() => merchantProfileRepository.update(any())).thenAnswer(
        (_) async => const Right(unit),
      );

      final result = await sut.execute(storeName: 'Shop');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected success'),
        (profile) => expect(profile.storeName, 'Shop'),
      );
      verifyNever(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      );
    });

    test('returns ValidationFailure when store name is empty', () async {
      final result = await sut.execute(storeName: '   ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'merchant_store_name_required'),
        (_) => fail('expected failure'),
      );
    });

    test('returns ValidationFailure when store name is too long', () async {
      final result = await sut.execute(storeName: 'x' * 101);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'merchant_store_name_too_long'),
        (_) => fail('expected failure'),
      );
    });

    test('returns ValidationFailure for invalid phone', () async {
      final result = await sut.execute(
        storeName: 'Shop',
        storePhone: 'not-a-phone',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'merchant_store_phone_invalid'),
        (_) => fail('expected failure'),
      );
    });

    test('creates profile when none exists', () async {
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => const Right(null),
      );
      when(() => merchantProfileRepository.update(any())).thenAnswer(
        (_) async => const Right(unit),
      );

      final result = await sut.execute(storeName: 'New Shop');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected success'),
        (profile) {
          expect(profile.storeName, 'New Shop');
          expect(profile.storePhone, isNull);
        },
      );
    });

    test('returns repository failure when merchant profile read fails', () async {
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => const Left(DatabaseFailure('read failed')),
      );

      final result = await sut.execute(storeName: 'Shop');

      expect(result.isLeft(), isTrue);
    });

    test('returns repository failure on update', () async {
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => Right(existingProfile()),
      );
      when(() => merchantProfileRepository.update(any())).thenAnswer(
        (_) async => const Left(DatabaseFailure('write failed')),
      );

      final result = await sut.execute(storeName: 'Updated');

      expect(result.isLeft(), isTrue);
    });
  });

  group('SetMerchantLogoUseCase', () {
    test('returns LimitExceededFailure when branding is locked', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => false);
      final sut = SetMerchantLogoUseCase(
        merchantProfileRepository,
        activationRepository,
        () async => throw StateError('should not resolve'),
      );

      final result = await sut.execute(sourcePath: '/tmp/logo.png');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<LimitExceededFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('returns StorageFailure when documents directory fails', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => true);
      final sut = SetMerchantLogoUseCase(
        merchantProfileRepository,
        activationRepository,
        () async => throw Exception('no documents'),
      );

      final result = await sut.execute(sourcePath: '/tmp/logo.png');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<StorageFailure>());
          expect(failure.code, 'merchant_logo_documents_unavailable');
        },
        (_) => fail('expected failure'),
      );
    });

    test('returns failure when profile does not exist', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => true);
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => const Right(null),
      );
      final sut = SetMerchantLogoUseCase(
        merchantProfileRepository,
        activationRepository,
        () async => throw StateError('processor should fail first'),
      );

      final result = await sut.execute(sourcePath: '/missing/file.png');

      expect(result.isLeft(), isTrue);
    });
  });

  group('ClearMerchantLogoUseCase', () {
    test('returns LimitExceededFailure when branding is locked', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => false);
      final sut = ClearMerchantLogoUseCase(
        merchantProfileRepository,
        activationRepository,
      );

      final result = await sut.execute();

      expect(result.isLeft(), isTrue);
    });

    test('delegates to repository when branding is unlocked', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => true);
      when(() => merchantProfileRepository.clearLogo()).thenAnswer(
        (_) async => const Right(unit),
      );
      final sut = ClearMerchantLogoUseCase(
        merchantProfileRepository,
        activationRepository,
      );

      final result = await sut.execute();

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => merchantProfileRepository.clearLogo()).called(1);
    });
  });
}
