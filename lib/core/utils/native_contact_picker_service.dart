import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:daftar/core/utils/whatsapp_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Name + optional phone from the OS contacts picker.
final class NativeContactPickResult {
  const NativeContactPickResult({
    required this.name,
    this.phone,
  });

  final String name;
  final String? phone;
}

/// Outcome of a native contacts pick. Deny is distinct from cancel.
sealed class NativeContactPickOutcome {
  const NativeContactPickOutcome();
}

/// Merchant picked a contact.
final class NativeContactPicked extends NativeContactPickOutcome {
  const NativeContactPicked(this.result);

  final NativeContactPickResult result;
}

/// Merchant dismissed the picker or the plugin is unavailable.
final class NativeContactCancelled extends NativeContactPickOutcome {
  const NativeContactCancelled();
}

/// OS contacts permission is denied (possibly permanently).
final class NativeContactDenied extends NativeContactPickOutcome {
  const NativeContactDenied({this.permanentlyDenied = false});

  final bool permanentlyDenied;
}

abstract final class NativeContactPickerService {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True when the OS already allows reading contacts (no prompt).
  static Future<bool> hasReadPermission() async {
    if (!isSupported) {
      return false;
    }
    final current = await FlutterContacts.permissions.check(
      PermissionType.read,
    );
    return isReadGranted(current);
  }

  /// Opens the OS picker. [NativeContactDenied] vs [NativeContactCancelled]
  /// are distinct so the UI can show Open Settings only on deny.
  static Future<NativeContactPickOutcome> pickNameAndPhone() async {
    if (!isSupported) {
      return const NativeContactCancelled();
    }

    try {
      final gate = await _ensureReadPermission();
      if (gate == _ContactReadGate.denied) {
        return const NativeContactDenied();
      }
      if (gate == _ContactReadGate.permanentlyDenied) {
        return const NativeContactDenied(permanentlyDenied: true);
      }

      final picked = await FlutterContacts.native.showPicker(
        properties: const {ContactProperty.phone},
      );
      if (picked == null) {
        return const NativeContactCancelled();
      }
      final mapped = mapPickedContact(picked);
      if (mapped == null) {
        return const NativeContactCancelled();
      }
      return NativeContactPicked(mapped);
    } on MissingPluginException catch (error, stackTrace) {
      developer.log(
        'Native contact picker plugin not registered',
        name: 'NativeContactPickerService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NativeContactCancelled();
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Native contact picker denied or failed: ${error.code}',
        name: 'NativeContactPickerService',
        error: error,
        stackTrace: stackTrace,
      );
      if (isPermissionDeniedCode(error.code)) {
        return const NativeContactDenied(permanentlyDenied: true);
      }
      return const NativeContactCancelled();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Native contact picker failed',
        name: 'NativeContactPickerService',
        error: error,
        stackTrace: stackTrace,
      );
      return const NativeContactCancelled();
    }
  }

  static bool isReadGranted(PermissionStatus status) {
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  /// Platform channel codes that mean the OS blocked contacts access.
  static bool isPermissionDeniedCode(String? code) {
    final normalized = (code ?? '').trim().toLowerCase();
    return normalized == 'permission_denied' ||
        normalized == 'permissiondenied';
  }

  static Future<_ContactReadGate> _ensureReadPermission() async {
    final current = await FlutterContacts.permissions.check(
      PermissionType.read,
    );
    final fromCurrent = _gateFromStatus(current, afterRequest: false);
    if (fromCurrent != null) {
      return fromCurrent;
    }

    final requested = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return _gateFromStatus(requested, afterRequest: true) ??
        _ContactReadGate.denied;
  }

  static _ContactReadGate? _gateFromStatus(
    PermissionStatus status, {
    required bool afterRequest,
  }) {
    if (isReadGranted(status)) {
      return _ContactReadGate.allowed;
    }
    if (status == PermissionStatus.permanentlyDenied ||
        status == PermissionStatus.restricted) {
      return _ContactReadGate.permanentlyDenied;
    }
    if (afterRequest && status == PermissionStatus.denied) {
      return _ContactReadGate.denied;
    }
    if (!afterRequest &&
        (status == PermissionStatus.denied ||
            status == PermissionStatus.notDetermined)) {
      return null;
    }
    if (afterRequest) {
      return _ContactReadGate.denied;
    }
    return null;
  }

  static NativeContactPickResult? mapPickedContact(Contact contact) {
    final displayName = (contact.displayName ?? '').trim();
    final structuredName = contact.name;
    final fallbackName = structuredName == null
        ? ''
        : '${structuredName.first} ${structuredName.last}'.trim();
    final name = displayName.isNotEmpty ? displayName : fallbackName;
    final rawPhone = _resolveRawPhone(contact);
    final sanitizedPhone = rawPhone == null
        ? null
        : WhatsAppUtil.sanitizePhone(rawPhone);
    final phone = sanitizedPhone != null && sanitizedPhone.isNotEmpty
        ? sanitizedPhone
        : null;

    if (name.isEmpty && phone == null) {
      return null;
    }

    return NativeContactPickResult(name: name, phone: phone);
  }

  static String? _resolveRawPhone(Contact contact) {
    if (contact.phones.isEmpty) {
      return null;
    }

    Phone? preferred;
    for (final phone in contact.phones) {
      if (phone.isPrimary == true) {
        preferred = phone;
        break;
      }
    }

    if (preferred == null) {
      for (final phone in contact.phones) {
        final label = phone.label.label;
        if (label == PhoneLabel.mobile || label == PhoneLabel.workMobile) {
          preferred = phone;
          break;
        }
      }
    }

    preferred ??= contact.phones.first;

    final trimmed = preferred.number.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

enum _ContactReadGate { allowed, denied, permanentlyDenied }
