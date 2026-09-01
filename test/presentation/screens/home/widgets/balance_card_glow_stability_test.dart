import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/transaction_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'balance_card_test_harness.dart';

void main() {
  testWidgets(
    'BalanceCard glow opacity stays stable across expand and collapse',
    (tester) async {
      final database = createBalanceCardTestDatabase();
      final container = createBalanceCardTestContainer(database);

      final ledger = (await container.read(ledgerRepositoryProvider).create(
        const CreateLedgerParams(
          name: 'Balance Card Ledger',
          type: LedgerType.custom,
          icon: 'ledger',
          color: '#1565C0',
        ),
      )).getRight().toNullable()!;

      final contact = (await container.read(contactRepositoryProvider).create(
        CreateContactParams(
          ledgerId: ledger.id,
          name: 'Glow Stability Contact',
          avatarColor: '#FF9800',
          creditCurrency: DbConstants.currencyYer,
        ),
      )).getRight().toNullable()!;

      await pumpBalanceCardTestApp(tester, database: database);

      await container.read(transactionControllerProvider.notifier).addTransaction(
        contactId: contact.id,
        type: TransactionType.debt,
        amount: 500,
        currency: DbConstants.currencyYer,
        description: 'Seed balance for glow stability test',
        transactionDate: DateTime.utc(2026),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      final balanceCard = find.byType(BalanceCard);
      expect(balanceCard, findsOneWidget);

      final innerGlowOpacity = _innerHorizonGlowOpacity(tester, balanceCard);
      expect(innerGlowOpacity, greaterThan(0.0));

      final expandTapTarget = find.descendant(
        of: balanceCard,
        matching: find.byType(GestureDetector),
      ).first;

      await tester.tap(expandTapTarget, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(_innerHorizonGlowOpacity(tester, balanceCard), innerGlowOpacity);

      await tester.tap(expandTapTarget, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(_innerHorizonGlowOpacity(tester, balanceCard), innerGlowOpacity);

      container.dispose();
      await database.close();
    },
  );
}

double _innerHorizonGlowOpacity(WidgetTester tester, Finder balanceCard) {
  final innerGlowFinder = find.descendant(
    of: balanceCard,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is AnimatedOpacity &&
          widget.duration == AppDimensions.animationXSlow,
    ),
  );
  expect(innerGlowFinder, findsOneWidget);
  return tester.widget<AnimatedOpacity>(innerGlowFinder).opacity;
}
