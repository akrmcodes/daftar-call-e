import 'package:daftar/application/settings/set_calle_allow_dial_use_case.dart';
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

  test('execute persists calleAllowDial on', () async {
    final repository = MockSettingsRepository();
    when(() => repository.update(any())).thenAnswer(
      (_) async => const Right(AppSettings(calleAllowDial: true)),
    );

    final result = await SetCalleAllowDialUseCase(
      repository,
    ).execute(enabled: true);

    expect(result.getRight().toNullable()?.calleAllowDial, isTrue);
    final captured =
        verify(() => repository.update(captureAny())).captured.single
            as UpdateSettingsParams;
    expect(captured.calleAllowDial, isTrue);
  });

  test('execute can turn CALL-E outbound off', () async {
    final repository = MockSettingsRepository();
    when(() => repository.update(any())).thenAnswer(
      (_) async => const Right(AppSettings()),
    );

    final result = await SetCalleAllowDialUseCase(
      repository,
    ).execute(enabled: false);

    expect(result.getRight().toNullable()?.calleAllowDial, isFalse);
    final captured =
        verify(() => repository.update(captureAny())).captured.single
            as UpdateSettingsParams;
    expect(captured.calleAllowDial, isFalse);
  });
}
