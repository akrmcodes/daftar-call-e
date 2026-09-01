import 'package:daftar/application/auto_backup/auto_backup_battery_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('markPromptShown persists and suppresses shouldPrompt', () async {
    await AutoBackupBatteryGate.markPromptShown();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AutoBackupBatteryGate.prefsKeyShown), isTrue);
    expect(await AutoBackupBatteryGate.shouldPrompt(), isFalse);
  });

  test('aggressive OEM set includes MENA-relevant brands', () {
    expect(
      AutoBackupBatteryGate.aggressiveOemManufacturers,
      containsAll(<String>['xiaomi', 'huawei', 'samsung', 'oppo']),
    );
  });
}
