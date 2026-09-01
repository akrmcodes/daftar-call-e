import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/activation_secure_storage_ds.dart';
import 'package:daftar/data/datasources/remote/activation_api_ds.dart';
import 'package:daftar/data/repositories/activation_repository_impl.dart';
import 'package:daftar/data/services/entitlement_payload_codec.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActivationApiDs extends Mock implements ActivationApiDs {}

String buildValidOfflineProCode() {
  const prefix = AppConstants.offlineProCodePrefix;
  for (var i = 0; i < 1000000; i++) {
    final suffix = i.toString().padLeft(12, '0');
    final code = '$prefix$suffix';
    if (code.length != AppConstants.offlineProCodeLength) {
      continue;
    }
    var sum = 0;
    for (final unit in code.codeUnits) {
      sum += unit;
    }
    if (sum % 97 == 0) {
      return code;
    }
  }
  throw StateError('unable to build valid offline Pro code');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late MockActivationApiDs mockApiDs;
  late EntitlementPayloadCodec codec;
  late ActivationRepositoryImpl repository;

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    mockApiDs = MockActivationApiDs();
    codec = EntitlementPayloadCodec();
    repository = ActivationRepositoryImpl(
      activationApiDs: mockApiDs,
      secureStorageDs: ActivationSecureStorageDs(
        storage: const FlutterSecureStorage(),
      ),
      codec: codec,
    );
  });

  group('activation integration', () {
    test('persists Pro entitlement from online activation', () async {
      final token = codec.encodeOffline(Entitlement.forPro());
      when(
        () => mockApiDs.activate(code: any(named: 'code')),
      ).thenAnswer((_) async => token);

      final activateResult = await repository.activate('ONLINE-CODE-123');
      expect(activateResult.isRight(), isTrue);
      activateResult.fold(
        (_) => fail('expected success'),
        (entitlement) {
          expect(entitlement.tier, AppTier.pro);
          expect(entitlement.hasUnlimitedContacts, isTrue);
        },
      );

      final storedToken = vault[AppConstants.entitlementTokenStorageKey];
      expect(storedToken, isNotNull);
      final persisted = codec.decode(storedToken!);
      expect(persisted?.tier, AppTier.pro);
      expect(persisted?.hasUnlimitedContacts, isTrue);
    });

    test('falls back to offline validation when API is unreachable', () async {
      when(
        () => mockApiDs.activate(code: any(named: 'code')),
      ).thenThrow(
        const ServerException('network'),
      );

      final validCode = buildValidOfflineProCode();
      final validResult = await repository.activate(validCode);
      expect(validResult.isRight(), isTrue);
      validResult.fold(
        (_) => fail('expected success'),
        (entitlement) => expect(entitlement.tier, AppTier.pro),
      );
      expect(
        vault[AppConstants.entitlementTokenStorageKey],
        isNotNull,
      );

      vault.clear();
      when(
        () => mockApiDs.activate(code: any(named: 'code')),
      ).thenThrow(
        const ServerException('network'),
      );

      final invalidResult = await repository.activate('INVALID');
      expect(invalidResult.isLeft(), isTrue);
      invalidResult.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'invalid_offline_code');
        },
        (_) => fail('expected failure'),
      );
    });
  });
}
