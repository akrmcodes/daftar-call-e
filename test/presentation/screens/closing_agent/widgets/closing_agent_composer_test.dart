import 'dart:async';

import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_composer.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_voice_chamber.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness({
    required TextEditingController controller,
    required bool isRecording,
    required bool isRunning,
    required VoidCallback onMicTap,
    required VoidCallback onMicHoldStart,
    required VoidCallback onMicHoldEnd,
    required VoidCallback onMicHoldCancel,
    ValueChanged<String>? onSubmit,
    bool disableAnimations = false,
    Stream<double>? amplitudeStream,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: ClosingAgentComposer(
            controller: controller,
            isRunning: isRunning,
            sendIsPrimary: true,
            isRecording: isRecording,
            amplitudeStream: amplitudeStream,
            onSubmit: onSubmit ?? (_) {},
            onMicTap: onMicTap,
            onMicHoldStart: onMicHoldStart,
            onMicHoldEnd: onMicHoldEnd,
            onMicHoldCancel: onMicHoldCancel,
          ),
        ),
      ),
    );
  }

  testWidgets('mic short tap is hold hint; coming-soon is gone', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    var submits = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        isRecording: false,
        isRunning: false,
        onSubmit: (_) => submits++,
        onMicTap: () => taps++,
        onMicHoldStart: () => holds++,
        onMicHoldEnd: () {},
        onMicHoldCancel: () {},
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_outlined));
    await tester.pump();

    expect(taps, 1);
    expect(holds, 0);
    expect(submits, 0);
    expect(find.textContaining('coming soon'), findsNothing);
    expect(find.textContaining('Voice is coming soon'), findsNothing);
  });

  testWidgets('mic long-press starts hold-to-talk without submitting', (
    tester,
  ) async {
    var holds = 0;
    var ends = 0;
    var submits = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        isRecording: false,
        isRunning: false,
        onSubmit: (_) => submits++,
        onMicTap: () {},
        onMicHoldStart: () => holds++,
        onMicHoldEnd: () => ends++,
        onMicHoldCancel: () {},
      ),
    );

    await tester.longPress(find.byIcon(Icons.mic_outlined));
    await tester.pump();

    expect(holds, 1);
    expect(ends, 1);
    expect(submits, 0);
  });

  testWidgets('recording morph shows voice chamber and hides send', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        isRecording: true,
        isRunning: false,
        onMicTap: () {},
        onMicHoldStart: () {},
        onMicHoldEnd: () {},
        onMicHoldCancel: () {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ClosingAgentVoiceChamber), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.text('Slide up to cancel'), findsOneWidget);
  });

  testWidgets('slide-up past threshold cancels instead of submitting', (
    tester,
  ) async {
    var cancelled = false;
    var ended = false;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        isRecording: true,
        isRunning: false,
        onMicTap: () {},
        onMicHoldStart: () {},
        onMicHoldEnd: () => ended = true,
        onMicHoldCancel: () => cancelled = true,
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.mic_rounded)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(find.text('Release to cancel'), findsOneWidget);
    await gesture.up();
    await tester.pump();

    expect(cancelled, isTrue);
    expect(ended, isFalse);
  });

  testWidgets('voice chamber reduce motion renders static ribbon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ClosingAgentVoiceChamber(
              cancelArmed: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Recording'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('cancel hint does not overflow on narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: Size(160, 640)),
          child: Scaffold(
            body: ClosingAgentVoiceChamber(
              cancelArmed: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Release to cancel'), findsOneWidget);
  });

  testWidgets('composer hint and mic are present; focus does not overflow', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        isRecording: false,
        isRunning: false,
        onMicTap: () {},
        onMicHoldStart: () {},
        onMicHoldEnd: () {},
        onMicHoldCancel: () {},
      ),
    );
    await tester.pump();

    expect(find.text('Write in the ledger'), findsOneWidget);
    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.spellCheckConfiguration,
      const SpellCheckConfiguration.disabled(),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('isRunning shows vault arc and disables field', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        isRecording: false,
        isRunning: true,
        onMicTap: () {},
        onMicHoldStart: () {},
        onMicHoldEnd: () {},
        onMicHoldCancel: () {},
      ),
    );
    await tester.pump();

    expect(find.text('Reconciling ledger entries...'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
