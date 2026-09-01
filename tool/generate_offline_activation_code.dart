// CLI tool — intentional stdout for copy/paste during QA.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/data/services/offline_activation_validator.dart';
import 'package:daftar/domain/enums/app_tier.dart';

/// Generates valid offline activation codes for local QA (mod-97 checksum).
///
/// Usage:
/// ```sh
/// dart run tool/generate_offline_activation_code.dart proplus
/// dart run tool/generate_offline_activation_code.dart pro
/// ```
void main(List<String> args) {
  final tierArg = (args.isEmpty ? 'proplus' : args.first).toLowerCase();
  final tier = switch (tierArg) {
    'pro' => AppTier.pro,
    'proplus' || 'pro+' || 'pro_plus' => AppTier.proPlus,
    _ => null,
  };

  if (tier == null) {
    print('Usage: dart run tool/generate_offline_activation_code.dart [pro|proplus]');
    exitCode = 64;
    return;
  }

  final code = _generateCode(tier);
  final validated = OfflineActivationValidator.validateTier(code);

  if (validated != tier) {
    print('Internal error: generated code failed validation ($code)');
    exitCode = 1;
    return;
  }

  print(code);
}

String _generateCode(AppTier tier) {
  final prefix = switch (tier) {
    AppTier.pro => AppConstants.offlineProCodePrefix,
    AppTier.proPlus => AppConstants.offlineProPlusCodePrefix,
    AppTier.free => throw ArgumentError('free tier has no offline code'),
  };
  final totalLength = switch (tier) {
    AppTier.pro => AppConstants.offlineProCodeLength,
    AppTier.proPlus => AppConstants.offlineProPlusCodeLength,
    AppTier.free => throw ArgumentError('free tier has no offline code'),
  };

  const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  final bodyLength = totalLength - prefix.length - 1;

  while (true) {
    final buffer = StringBuffer(prefix);
    for (var i = 0; i < bodyLength; i++) {
      buffer.write(charset[random.nextInt(charset.length)]);
    }

    final partial = buffer.toString();
    final partialSum = partial.codeUnits.fold<int>(0, (sum, unit) => sum + unit);

    for (var i = 0; i < charset.length; i++) {
      final candidate = '$partial${charset[i]}';
      if (candidate.length != totalLength) {
        continue;
      }
      final sum = partialSum + charset.codeUnitAt(i);
      if (sum % 97 == 0) {
        return candidate;
      }
    }
  }
}
