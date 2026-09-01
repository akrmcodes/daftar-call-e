// CLI helper — intentional stdout for LAN QA checks.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:daftar/core/env/env.dart';

/// Verifies envied baked `ACTIVATION_API_BASE_URL` contains the given LAN IP.
///
/// Usage:
/// ```sh
/// dart run tool/verify_lan_env.dart 192.168.8.81
/// ```
void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run tool/verify_lan_env.dart <LAN_IP>');
    exitCode = 64;
    return;
  }

  final ip = args.first;
  final url = Env.activationApiBaseUrl;
  final ok = url.contains(ip) && url.contains(':54321/functions/v1');

  print(ok ? 'OK' : 'FAIL');
  print('activation_api_base_url=$url');
  print('expected_ip=$ip');

  if (!ok) {
    exitCode = 1;
  }
}
