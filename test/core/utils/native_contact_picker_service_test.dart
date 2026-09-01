import 'package:daftar/core/utils/native_contact_picker_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NativeContactPickerService.mapPickedContact', () {
    test('maps display name and mobile phone with sanitization', () {
      final result = NativeContactPickerService.mapPickedContact(
        const Contact(
          displayName: '  أحمد علي  ',
          phones: [
            Phone(
              number: '+967 77 123 4567',
              label: Label(PhoneLabel.mobile),
            ),
          ],
        ),
      );

      expect(result, isNotNull);
      expect(result!.name, 'أحمد علي');
      expect(result.phone, '967771234567');
    });

    test('falls back to first phone when mobile label is absent', () {
      final result = NativeContactPickerService.mapPickedContact(
        const Contact(
          displayName: 'Sara',
          phones: [
            Phone(
              number: '050 111 2222',
              label: Label(PhoneLabel.home),
            ),
          ],
        ),
      );

      expect(result, isNotNull);
      expect(result!.name, 'Sara');
      expect(result.phone, '0501112222');
    });

    test('returns null when name and phone are both empty', () {
      final result = NativeContactPickerService.mapPickedContact(
        const Contact(),
      );

      expect(result, isNull);
    });
  });

  group('NativeContactPickerService permission codes', () {
    test('permission_denied is a deny, not a cancel', () {
      expect(
        NativeContactPickerService.isPermissionDeniedCode('permission_denied'),
        isTrue,
      );
      expect(
        NativeContactPickerService.isPermissionDeniedCode('PERMISSIONDENIED'),
        isTrue,
      );
      expect(
        NativeContactPickerService.isPermissionDeniedCode('cancelled'),
        isFalse,
      );
    });

    test('granted and limited count as read access', () {
      expect(
        NativeContactPickerService.isReadGranted(PermissionStatus.granted),
        isTrue,
      );
      expect(
        NativeContactPickerService.isReadGranted(PermissionStatus.limited),
        isTrue,
      );
      expect(
        NativeContactPickerService.isReadGranted(PermissionStatus.denied),
        isFalse,
      );
      expect(
        NativeContactPickerService.isReadGranted(
          PermissionStatus.permanentlyDenied,
        ),
        isFalse,
      );
    });
  });
}
