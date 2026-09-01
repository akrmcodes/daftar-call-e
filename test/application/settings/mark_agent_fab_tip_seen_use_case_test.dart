import 'package:daftar/application/settings/mark_agent_fab_tip_seen_use_case.dart';
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

  test('execute persists hasSeenAgentFabTip true', () async {
    final repository = MockSettingsRepository();
    when(() => repository.update(any())).thenAnswer(
      (_) async => const Right(AppSettings(hasSeenAgentFabTip: true)),
    );

    final result = await MarkAgentFabTipSeenUseCase(repository).execute();

    expect(result.getRight().toNullable()?.hasSeenAgentFabTip, isTrue);
    final captured =
        verify(() => repository.update(captureAny())).captured.single
            as UpdateSettingsParams;
    expect(captured.hasSeenAgentFabTip, isTrue);
  });
}
