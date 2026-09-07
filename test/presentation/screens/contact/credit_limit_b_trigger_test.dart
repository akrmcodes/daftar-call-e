import 'dart:async' show unawaited;

import 'package:daftar/app/router/app_router.dart';
import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/constants/calle_device_policy.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/providers/balance_providers.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/contact/credit_limit_b_trigger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const contactId = 'contact-prepare';
  const usPhone = '+15555550100';
  final now = DateTime.utc(2026, 9, 8);
  const callePolicy = CalleDevicePolicy(
    allowDial: false,
    allowlist: const {},
    allowlistRegion: 'US',
  );
  final balance = ContactBalance(
    contactId: contactId,
    currencyCode: 'YER',
    totalDebt: 150000,
    totalPayment: 0,
    netBalance: -150000,
    lastUpdatedAt: now,
  );

  Contact contactWithPhone(String? phone) => Contact(
    id: contactId,
    ledgerId: 'ledger',
    name: 'Ahmed',
    avatarColor: '#111111',
    createdAt: now,
    updatedAt: now,
    creditLimit: 100000,
    creditCurrency: 'YER',
    phone: phone,
  );

  Future<void> pumpHost(
    WidgetTester tester, {
    required Contact contact,
    required _RecordingClosingAgent recording,
    required GoRouter router,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          closingAgentControllerProvider.overrideWith(() => recording),
          calleDevicePolicyProvider.overrideWithValue(callePolicy),
          contactByIdProvider(contactId).overrideWith(
            (ref) async => Right<Failure, Contact>(contact),
          ),
          contactBalanceProvider(contactId).overrideWith(
            (ref) => Stream<List<ContactBalance>>.value([balance]),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }

  GoRouter buildRouter() {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _HostPage(contactId: contactId),
        ),
        GoRoute(
          path: RouteNames.closingAgentPath,
          name: RouteNames.closingAgent,
          builder: (context, state) => const Scaffold(
            body: Text('closing-agent'),
          ),
        ),
      ],
    );
  }

  testWidgets('Prepare starts session after host route is popped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final recording = _RecordingClosingAgent();
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpHost(
      tester,
      contact: contactWithPhone(usPhone),
      recording: recording,
      router: router,
    );

    await tester.tap(find.text('open-host'));
    await tester.pumpAndSettle();
    expect(find.text('save-debt'), findsOneWidget);

    await tester.tap(find.text('save-debt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Prepare the call'), findsOneWidget);
    expect(find.text('save-debt'), findsNothing);

    await tester.tap(find.text('Prepare the call'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(recording.startedContactId, contactId);
    expect(recording.state.phase, ClosingAgentPhase.ritualDesk);
    expect(recording.state.callBatchTrigger, CallBatchTrigger.creditLimit);
    expect(find.text('closing-agent'), findsOneWidget);
  });

  testWidgets('YE phone does not show Prepare the call', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final recording = _RecordingClosingAgent();
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpHost(
      tester,
      contact: contactWithPhone('0771234567'),
      recording: recording,
      router: router,
    );

    await tester.tap(find.text('open-host'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save-debt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Prepare the call'), findsNothing);
    expect(recording.startedContactId, isNull);
  });

  testWidgets('empty phone does not show Prepare the call', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final recording = _RecordingClosingAgent();
    final router = buildRouter();
    addTearDown(router.dispose);

    await pumpHost(
      tester,
      contact: contactWithPhone(null),
      recording: recording,
      router: router,
    );

    await tester.tap(find.text('open-host'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save-debt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Prepare the call'), findsNothing);
    expect(recording.startedContactId, isNull);
  });
}

class _RecordingClosingAgent extends ClosingAgentController {
  String? startedContactId;

  @override
  ClosingAgentState build() => const ClosingAgentState();

  @override
  Future<void> startCreditLimitCallSession(String contactId) async {
    startedContactId = contactId;
    state = state.copyWith(
      phase: ClosingAgentPhase.ritualDesk,
      callBatchTrigger: CallBatchTrigger.creditLimit,
    );
  }
}

class _HostPage extends ConsumerWidget {
  const _HostPage({required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(contactByIdProvider(contactId))
      ..watch(contactBalanceProvider(contactId));
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            unawaited(
              showDialog<void>(
                context: context,
                builder: (dialogContext) {
                  return Consumer(
                    builder: (dialogContext, dialogRef, _) {
                      return AlertDialog(
                        content: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            unawaited(
                              CreditLimitBTrigger.offerAfterDebtSave(
                                context: dialogContext,
                                ref: dialogRef,
                                contactId: contactId,
                                type: TransactionType.debt,
                                warningLevel: CreditWarningLevel.exceeded,
                              ),
                            );
                          },
                          child: const Text('save-debt'),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
          child: const Text('open-host'),
        ),
      ),
    );
  }
}
