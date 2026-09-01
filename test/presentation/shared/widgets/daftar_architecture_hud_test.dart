import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/architecture_hud_provider.dart';
import 'package:daftar/presentation/shared/widgets/daftar_architecture_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _turnSnapshot = ArchitectureHudSnapshot(
  enabled: true,
  modelId: 'gemini-3.5-flash',
  toolNames: ['propose_debt'],
  toolScope: ArchitectureHudToolScope.capture,
  latencyMs: 420,
  correlationId: '550e8400-e29b-41d4-a716-446655440000',
  hitlStep: ArchitectureHudHitlStep.confirm,
  pendingCount: 1,
);

const _emailSnapshot = ArchitectureHudSnapshot(
  enabled: true,
  modelId: 'gemini-3.5-flash',
  toolNames: ['propose_closing_plan'],
  toolScope: ArchitectureHudToolScope.close,
  latencyMs: 880,
  correlationId: 'corr-abcd1234',
  hitlStep: ArchitectureHudHitlStep.rank,
  committedCount: 2,
  smtpMessageId: '<19c8a4f0d2abcdef@gmail.com>',
);

const _idleSnapshot = ArchitectureHudSnapshot(
  enabled: true,
  modelId: 'gemini-3.5-flash',
);

Widget _harness({
  required ArchitectureHudSnapshot snapshot,
  bool disableAnimations = true,
  Locale locale = const Locale('en'),
  VoidCallback? onFabPressed,
}) {
  return ProviderScope(
    overrides: [
      architectureHudSnapshotProvider.overrideWith((ref) => snapshot),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DaftarArchitectureHud(),
            if (onFabPressed != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: FloatingActionButton(
                  onPressed: onFabPressed,
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toggle off hides the overlay', (tester) async {
    await tester.pumpWidget(
      _harness(snapshot: const ArchitectureHudSnapshot(enabled: false)),
    );
    await tester.pump();

    expect(find.byKey(DaftarArchitectureHud.overlayKey), findsNothing);
    expect(find.textContaining('gemini-3.5-flash'), findsNothing);
    expect(find.textContaining('Cloud Run'), findsNothing);
  });

  testWidgets('toggle on shows pinned model routing rail and scope', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_harness(snapshot: _turnSnapshot));
      await tester.pump();

      expect(find.byKey(DaftarArchitectureHud.overlayKey), findsOneWidget);
      expect(
        find.bySemanticsLabel('Agent architecture instrument, step Confirm'),
        findsOneWidget,
      );
      expect(
        find.text('Cloud Run · gemini-3.5-flash'),
        findsOneWidget,
      );
      expect(find.text('420 ms'), findsOneWidget);
      expect(find.text('Ref 55440000'), findsOneWidget);
      expect(find.text('Capture'), findsOneWidget);
      expect(find.text('propose_debt'), findsOneWidget);
      expect(find.text('Propose'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Commit'), findsOneWidget);
      expect(find.text('Rank'), findsOneWidget);
      expect(find.text('Pending 1 · Recorded 0'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(
        find.textContaining('delivered', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('Delivered', findRichText: true),
        findsNothing,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('enabled with no turn still shows pinned model and rail', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(snapshot: _idleSnapshot));
    await tester.pump();

    expect(find.byKey(DaftarArchitectureHud.overlayKey), findsOneWidget);
    expect(find.text('Cloud Run · gemini-3.5-flash'), findsOneWidget);
    expect(find.text('Propose'), findsOneWidget);
  });

  testWidgets('email chip is sent plus Message-ID last-8, never delivered', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(snapshot: _emailSnapshot));
    await tester.pump();

    expect(find.text('Sent · d2abcdef'), findsOneWidget);
    expect(find.textContaining('delivered', findRichText: true), findsNothing);
    expect(find.textContaining('Delivered', findRichText: true), findsNothing);
  });

  testWidgets('running shows pending latency ellipsis', (tester) async {
    await tester.pumpWidget(
      _harness(
        snapshot: _turnSnapshot.copyWith(
          isRunning: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cloud Run · gemini-3.5-flash'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);
    expect(find.text('Ref 55440000'), findsOneWidget);
  });

  testWidgets('reduce-motion pumpAndSettle completes with static instrument', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(snapshot: _turnSnapshot));
    await tester.pumpAndSettle();

    expect(find.byKey(DaftarArchitectureHud.overlayKey), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('HUD IgnorePointer does not invoke FAB and does not block FAB taps', (
    tester,
  ) async {
    var fabTaps = 0;
    await tester.pumpWidget(
      _harness(
        snapshot: _turnSnapshot,
        onFabPressed: () => fabTaps += 1,
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(DaftarArchitectureHud.overlayKey),
      warnIfMissed: false,
    );
    expect(fabTaps, 0);

    await tester.tap(find.byType(FloatingActionButton));
    expect(fabTaps, 1);
  });

  testWidgets('Arabic rail labels render', (tester) async {
    await tester.pumpWidget(
      _harness(
        snapshot: _idleSnapshot,
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('اقتراح'), findsOneWidget);
    expect(find.text('تأكيد'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
    expect(find.text('ترتيب'), findsOneWidget);
  });

  testWidgets('HUD text has no underline decoration', (tester) async {
    await tester.pumpWidget(_harness(snapshot: _turnSnapshot));
    await tester.pump();

    final overlay = find.byKey(DaftarArchitectureHud.overlayKey);
    expect(overlay, findsOneWidget);

    for (final element in overlay.evaluate()) {
      for (final textFinder in find.descendant(
        of: find.byElementPredicate((e) => e == element),
        matching: find.byType(Text),
      ).evaluate()) {
        final widget = textFinder.widget as Text;
        final decoration = widget.style?.decoration;
        expect(
          decoration,
          isNot(TextDecoration.underline),
          reason: 'Text "${widget.data}" must not be underlined',
        );
        expect(
          decoration,
          isNot(TextDecoration.overline),
          reason: 'Text "${widget.data}" must not be overlined',
        );
      }
    }
  });

  testWidgets('English HUD labels use Inter not monospace', (tester) async {
    await tester.pumpWidget(_harness(snapshot: _turnSnapshot));
    await tester.pump();

    final labels = [
      'Cloud Run · gemini-3.5-flash',
      '420 ms',
      'Ref 55440000',
      'Capture',
      'propose_debt',
      'Propose',
      'Confirm',
      'Commit',
      'Rank',
      'Pending 1 · Recorded 0',
    ];

    for (final label in labels) {
      final text = tester.widget<Text>(find.text(label));
      expect(
        text.style?.fontFamily,
        AppTextStyles.latinFontFamily,
        reason: '$label should use Inter',
      );
      expect(
        text.style?.fontFamily,
        isNot('monospace'),
        reason: '$label must not use generic monospace',
      );
    }
  });

  testWidgets('HUD does not overflow at narrow width and large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          architectureHudSnapshotProvider.overrideWith((ref) => _turnSnapshot),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            );
          },
          home: const Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [DaftarArchitectureHud()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(DaftarArchitectureHud.overlayKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

extension on ArchitectureHudSnapshot {
  ArchitectureHudSnapshot copyWith({
    bool? enabled,
    bool? isRunning,
    String? modelId,
    List<String>? toolNames,
    ArchitectureHudToolScope? toolScope,
    int? latencyMs,
    String? correlationId,
    ArchitectureHudHitlStep? hitlStep,
    int? pendingCount,
    int? committedCount,
    int? skippedCount,
    String? smtpMessageId,
  }) {
    return ArchitectureHudSnapshot(
      enabled: enabled ?? this.enabled,
      isRunning: isRunning ?? this.isRunning,
      modelId: modelId ?? this.modelId,
      toolNames: toolNames ?? this.toolNames,
      toolScope: toolScope ?? this.toolScope,
      latencyMs: latencyMs ?? this.latencyMs,
      correlationId: correlationId ?? this.correlationId,
      hitlStep: hitlStep ?? this.hitlStep,
      pendingCount: pendingCount ?? this.pendingCount,
      committedCount: committedCount ?? this.committedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      smtpMessageId: smtpMessageId ?? this.smtpMessageId,
    );
  }
}
