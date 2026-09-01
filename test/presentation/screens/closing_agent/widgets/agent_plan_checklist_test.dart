import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/l10n/generated/app_localizations_en.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_plan_checklist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plan card narrates statement vs reminder split', (tester) async {
    final l10n = AppLocalizationsEn();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentPlanChecklist(
              steps: [
                ClosingPlanStep(title: 'Count today'),
              ],
              isConfirming: false,
              confirmIsPrimary: true,
              onConfirm: _noop,
              onSkip: _noop,
            ),
          ),
        ),
      ),
    );

    expect(find.text(l10n.closingAgentPlanTitle), findsOneWidget);
    expect(find.text(l10n.closingAgentPlanSendSplit), findsOneWidget);
    expect(find.text(l10n.closingAgentPlanDeviceRuns), findsOneWidget);
  });
}

void _noop() {}
