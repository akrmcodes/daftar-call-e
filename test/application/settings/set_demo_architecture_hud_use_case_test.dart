import 'package:daftar/application/settings/set_demo_architecture_hud_use_case.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const UpdateSettingsParams());
  });

  test('execute persists demoArchitectureHud', () async {
    final repository = MockSettingsRepository();
    when(() => repository.update(any())).thenAnswer(
      (_) async => const Right(AppSettings(demoArchitectureHud: true)),
    );

    final result = await SetDemoArchitectureHudUseCase(
      repository,
    ).execute(enabled: true);

    expect(result.getRight().toNullable()?.demoArchitectureHud, isTrue);
    final captured =
        verify(() => repository.update(captureAny())).captured.single
            as UpdateSettingsParams;
    expect(captured.demoArchitectureHud, isTrue);
  });

  test('execute can turn the HUD off', () async {
    final repository = MockSettingsRepository();
    when(() => repository.update(any())).thenAnswer(
      (_) async => const Right(AppSettings()),
    );

    final result = await SetDemoArchitectureHudUseCase(
      repository,
    ).execute(enabled: false);

    expect(result.getRight().toNullable()?.demoArchitectureHud, isFalse);
    final captured =
        verify(() => repository.update(captureAny())).captured.single
            as UpdateSettingsParams;
    expect(captured.demoArchitectureHud, isFalse);
  });
}
