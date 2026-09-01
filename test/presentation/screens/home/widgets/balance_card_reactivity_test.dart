import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/transaction_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'balance_card_test_harness.dart';

void main() {
  testWidgets(
    'BalanceCard reacts to transaction add, update, delete, and restore',
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
          name: 'Reactive Contact',
          avatarColor: '#FF9800',
          creditCurrency: DbConstants.currencyYer,
        ),
      )).getRight().toNullable()!;

      await pumpBalanceCardTestApp(tester, database: database);

      final balanceCard = find.byType(BalanceCard);
      expect(balanceCard, findsOneWidget);

      final heroCounter = find.descendant(
        of: balanceCard,
        matching: find.byType(AnimatedFlipCounter),
      );
      expect(heroCounter, findsWidgets);
      expect(
        tester.widget<AnimatedFlipCounter>(heroCounter.first).value.toInt(),
        0,
      );

      final controller = container.read(transactionControllerProvider.notifier);

      final created = (await controller.addTransaction(
        contactId: contact.id,
        type: TransactionType.debt,
        amount: 500,
        currency: DbConstants.currencyYer,
        description: 'Initial debt',
        transactionDate: DateTime.utc(2026),
      )).getRight().toNullable()!;

      final balancesAfterAdd = (await container
              .read(balanceRepositoryProvider)
              .getByContact(contact.id))
          .getRight()
          .toNullable()!;
      expect(balancesAfterAdd, hasLength(1));
      expect(balancesAfterAdd.single.netBalance, -500);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        tester.widget<AnimatedFlipCounter>(heroCounter.first).value.toInt(),
        500,
      );
      expect(
        find.descendant(of: balanceCard, matching: find.text('−')),
        findsOneWidget,
      );

      await controller.updateTransaction(
        transactionId: created.transaction.id,
        type: TransactionType.payment,
        amount: 200,
        currency: DbConstants.currencyYer,
        description: 'Edited to payment',
      );

      final balancesAfterUpdate = (await container
              .read(balanceRepositoryProvider)
              .getByContact(contact.id))
          .getRight()
          .toNullable()!;
      expect(balancesAfterUpdate, hasLength(1));
      expect(balancesAfterUpdate.single.netBalance, 200);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        tester.widget<AnimatedFlipCounter>(heroCounter.first).value.toInt(),
        200,
      );
      expect(
        find.descendant(of: balanceCard, matching: find.text('+')),
        findsOneWidget,
      );

      await controller.deleteTransaction(created.transaction.id);

      final balancesAfterDelete = (await container
              .read(balanceRepositoryProvider)
              .getByContact(contact.id))
          .getRight()
          .toNullable()!;
      expect(balancesAfterDelete, isEmpty);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        tester.widget<AnimatedFlipCounter>(heroCounter.first).value.toInt(),
        0,
      );

      await controller.restoreTransaction(created.transaction.id);

      final balancesAfterRestore = (await container
              .read(balanceRepositoryProvider)
              .getByContact(contact.id))
          .getRight()
          .toNullable()!;
      expect(balancesAfterRestore, hasLength(1));
      expect(balancesAfterRestore.single.netBalance, 200);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        tester.widget<AnimatedFlipCounter>(heroCounter.first).value.toInt(),
        200,
      );
      expect(
        find.descendant(of: balanceCard, matching: find.text('+')),
        findsOneWidget,
      );

      container.dispose();
      await database.close();
    },
  );
}
