import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/utils/security_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('SecurityService PIN', () {
    late MockFlutterSecureStorage storage;
    late SecurityService sut;
    final store = <String, String>{};

    setUp(() {
      store.clear();
      storage = MockFlutterSecureStorage();
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key]! as String;
        return store[key];
      });
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key]! as String;
        final value = invocation.namedArguments[#value] as String?;
        if (value == null) {
          store.remove(key);
        } else {
          store[key] = value;
        }
      });
      when(() => storage.delete(key: any(named: 'key')))
          .thenAnswer((invocation) async {
        store.remove(invocation.namedArguments[#key]! as String);
      });
      sut = SecurityService(storage: storage);
    });

    test('hasPinConfigured is false before setPin', () async {
      expect(await sut.hasPinConfigured(), isFalse);
    });

    test('setPin and validatePin succeed for matching PIN', () async {
      const pin = '1234';
      expect(await sut.setPin(pin), isTrue);
      expect(await sut.hasPinConfigured(), isTrue);
      expect(await sut.validatePin(pin), PinValidationResult.success);
    });

    test('validatePin returns incorrect for wrong PIN', () async {
      await sut.setPin('1234');
      expect(await sut.validatePin('0000'), PinValidationResult.incorrect);
    });

    test('validatePin rejects invalid format', () async {
      expect(
        await sut.validatePin('12'),
        PinValidationResult.invalidFormat,
      );
      expect(
        await sut.validatePin('abcd'),
        PinValidationResult.invalidFormat,
      );
    });

    test('clearPin removes configured PIN', () async {
      await sut.setPin('5678');
      await sut.clearPin();
      expect(await sut.hasPinConfigured(), isFalse);
      expect(
        await sut.validatePin('5678'),
        PinValidationResult.notConfigured,
      );
    });

    test('lockout after max failed attempts', () async {
      await sut.setPin('1234');
      for (var i = 0; i < AppConstants.maxFailedPinAttempts; i++) {
        await sut.validatePin('0000');
      }
      expect(
        await sut.validatePin('1234'),
        PinValidationResult.lockedOut,
      );
      expect(await sut.lockoutRemaining(), isNotNull);
    });
  });
}
