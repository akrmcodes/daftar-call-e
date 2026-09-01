// Benchmark telemetry prints structured METRIC lines to stdout for CI capture.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:daftar/app/app.dart';
import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/main.dart' as app_main;
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/ledger_list_tile.dart';
import 'package:daftar/presentation/screens/ledger/widgets/contact_list_tile.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// ============================================================================
/// DAFTAR PERFORMANCE TELEMETRY — UI SCROLL JANK BENCHMARKS
/// ============================================================================
///
/// Measures real frame timings during automated scrolls of the heaviest
/// UI lists in the app. Uses `SchedulerBinding.addTimingsCallback` to
/// capture raw FrameTiming data and compute:
///   - p50, p95, max frame durations
///   - Jank frame count (> 16.67ms budget)
///   - Severe jank count (> 33.33ms — visually obvious stutter)
///
/// REQUIRES a physical device. The test seeds the DB with realistic data
/// volumes, launches the full DaftarApp, and captures frame timings during
/// automated scrolls.
///
/// Run with:
///   flutter test integration_test/ui_scroll_benchmark_test.dart \
///     -d `DEVICE_ID` --no-pub --profile
///
/// The --profile flag compiles in profile mode, critical for accurate
/// frame timing on real hardware (debug mode has ~2x frame overhead).
/// ============================================================================

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI Frame Timing — Seeded scroll benchmark', (tester) async {
    // ── Setup: Create test database with realistic data volume ────────

    final tempRoot = await getTemporaryDirectory();
    final testDir = await Directory(
      p.join(
        tempRoot.path,
        'ui_bench_${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);

    // Same open path as production: runs migrations, seeds defaults, and
    // blocks until the background isolate finishes schema creation.
    final database = await openDatabase(documentsDirectory: testDir);

    // Confirm the onCreate migration seeded the singleton settings row before
    // mutating onboarding state.
    await database.select(database.appSettingsTable).getSingle();
    await (database.update(database.appSettingsTable)
          ..where((t) => t.id.equals(DbConstants.appSettingsId)))
        .write(
      const db.AppSettingsTableCompanion(
        hasSeenOnboarding: Value(true),
      ),
    );

    // ── Seed realistic data: 1 ledger, 100 contacts ─────────────────

    const stressContactIndex = 0;
    const stressTxnCount = 500;
    const defaultTxnCount = 20;

    final random = Random(42);
    late final String stressContactName;
    final seedLedger = LedgerModel(
      id: UuidUtil.generate(),
      name: 'دفتر الحسابات الرئيسي',
      type: LedgerType.customers,
      icon: 'ledger',
      color: '#FF1565C0',
      sortOrder: 0,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    await database.into(database.ledgers).insert(seedLedger.toDrift());

    final contactIds = <String>[];
    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║   SEEDING DATABASE FOR UI BENCHMARK...                  ║');
    print('╠══════════════════════════════════════════════════════════╣');

    await database.transaction(() async {
      for (var c = 0; c < 100; c++) {
        final contact = ContactModel(
          id: UuidUtil.generate(),
          ledgerId: seedLedger.id,
          name: _arabicName(random),
          phone:
              '+967${random.nextInt(999999999).toString().padLeft(9, '0')}',
          notes: c.isEven ? 'ملاحظات تجريبية' : null,
          creditLimit: c < 20 ? 50000 : null,
          creditCurrency: c < 20 ? 'YER' : null,
          avatarColor:
              '#FF${random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        contactIds.add(contact.id);
        if (c == stressContactIndex) {
          stressContactName = contact.name;
        }
        await database.into(database.contacts).insert(contact.toDrift());
        await upsertContactSearchIndex(database, contact.id, contact.name);

        final txnCount =
            c == stressContactIndex ? stressTxnCount : defaultTxnCount;
        var totalDebt = 0;
        var totalPayment = 0;
        for (var t = 0; t < txnCount; t++) {
          final type = random.nextBool()
              ? TransactionType.debt
              : TransactionType.payment;
          final amount = random.nextInt(50000) + 500;
          if (type == TransactionType.debt) {
            totalDebt += amount;
          } else {
            totalPayment += amount;
          }
          final txn = TransactionModel(
            id: UuidUtil.generate(),
            contactId: contact.id,
            type: type,
            amount: amount,
            currency: 'YER',
            description: 'معاملة تجريبية #$t',
            itemName: _arabicItem(random),
            transactionDate: DateTime.now()
                .toUtc()
                .subtract(Duration(days: random.nextInt(365))),
            attachmentPath: null,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );
          await database.into(database.transactions).insert(txn.toDrift());
        }

        // Seed denormalized balance
        await database
            .into(database.contactBalances)
            .insertOnConflictUpdate(
              BalanceModel(
                contactId: contact.id,
                currencyCode: 'YER',
                totalDebt: totalDebt,
                totalPayment: totalPayment,
                netBalance: totalPayment - totalDebt,
                lastUpdatedAt: DateTime.now().toUtc(),
              ).toDrift(),
            );
      }
    });

    print(
      '║   Seeded: 1 ledger, 100 contacts, 2480 transactions   ║',
    );
    print(
      '║   (500 transactions on stress contact)                  ║',
    );
    print('╠══════════════════════════════════════════════════════════╣');
    print('║   STARTING FRAME TIMING CAPTURE...                      ║');
    print('╠══════════════════════════════════════════════════════════╣');
    print('');

    // ── Bootstrap the full app with the seeded database ───────────────

    app_main.activeDatabase = database;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => app_main.activeDatabase),
        appDocumentsDirectoryProvider.overrideWith((ref) => testDir),
        backupPublicExportEnabledProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);
    app_main.appContainer = container;

    // Launch the full app
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DaftarApp(),
      ),
    );

    // Let the app fully settle (providers, streams, initial build)
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── Frame timing capture infrastructure ──────────────────────────

    final allTimings = <FrameTiming>[];

    void timingsCallback(List<FrameTiming> timings) {
      allTimings.addAll(timings);
    }

    // ── Scroll test: Home Screen ─────────────────────────────────────

    print('--- Phase 1: Home Screen Scroll ---');
    SchedulerBinding.instance.addTimingsCallback(timingsCallback);

    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      // Scroll down
      for (var i = 0; i < 10; i++) {
        await tester.drag(scrollables.first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      // Scroll back up
      for (var i = 0; i < 10; i++) {
        await tester.drag(scrollables.first, const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
    }

    SchedulerBinding.instance.removeTimingsCallback(timingsCallback);
    _emitFrameReport('UI_HOME_SCROLL', allTimings);
    allTimings.clear();

    // ── Navigate to ledger detail (100 contacts list) ────────────────

    print('--- Phase 2: Ledger Detail Scroll (100 contacts) ---');

    final ledgerTile = find.byType(LedgerListTile);
    if (ledgerTile.evaluate().isNotEmpty) {
      final navigatedToLedger = await _tapWhenVisible(tester, ledgerTile);

      if (navigatedToLedger &&
          find.byType(ContactListTile).evaluate().isNotEmpty) {
        SchedulerBinding.instance.addTimingsCallback(timingsCallback);

        // Aggressively scroll the contact list
        final detailScrollables = find.byType(Scrollable);
        if (detailScrollables.evaluate().isNotEmpty) {
          for (var i = 0; i < 20; i++) {
            await tester.drag(detailScrollables.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpAndSettle();

          for (var i = 0; i < 20; i++) {
            await tester.drag(detailScrollables.first, const Offset(0, 400));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpAndSettle();
        }

        SchedulerBinding.instance.removeTimingsCallback(timingsCallback);
        _emitFrameReport('UI_LEDGER_DETAIL_SCROLL_100C', allTimings);
        allTimings.clear();

        // ── Navigate to contact detail (500 transactions) ───────────

        print('--- Phase 3: Contact Detail Scroll (500 transactions) ---');

        final stressContactTile = find.ancestor(
          of: find.text(stressContactName),
          matching: find.byType(ContactListTile),
        );
        final contactTarget = stressContactTile.evaluate().isNotEmpty
            ? stressContactTile
            : find.byType(ContactListTile);

        if (contactTarget.evaluate().isNotEmpty) {
          final navigatedToContact =
              await _tapWhenVisible(tester, contactTarget);

          if (navigatedToContact &&
              find.byType(Scrollable).evaluate().isNotEmpty) {
            SchedulerBinding.instance.addTimingsCallback(timingsCallback);

            final txnScrollables = find.byType(Scrollable);
            for (var i = 0; i < 25; i++) {
              await tester.drag(
                txnScrollables.first,
                const Offset(0, -300),
              );
              await tester.pump(const Duration(milliseconds: 16));
            }
            await tester.pumpAndSettle();
            for (var i = 0; i < 25; i++) {
              await tester.drag(
                txnScrollables.first,
                const Offset(0, 300),
              );
              await tester.pump(const Duration(milliseconds: 16));
            }
            await tester.pumpAndSettle();

            SchedulerBinding.instance.removeTimingsCallback(timingsCallback);
            _emitFrameReport('UI_CONTACT_DETAIL_SCROLL_500T', allTimings);
            allTimings.clear();
          } else {
            print('SKIP: Contact navigation failed.');
          }
        } else {
          print('SKIP: Stress contact tile not found in ledger detail.');
        }
      } else {
        print('SKIP: Ledger navigation failed.');
        print('  Hit-test may have missed — verify LedgerListTile is visible.');
      }
    } else {
      print('SKIP: Ledger card not found in UI.');
      print('  The app may require onboarding/auth before reaching home.');
      print('  DB on-device benchmarks still provide valid data-layer metrics.');
    }

    print('');
    print('╔══════════════════════════════════════════════════════════╗');
    print('║   UI SCROLL BENCHMARKS COMPLETE                         ║');
    print('╚══════════════════════════════════════════════════════════╝');
    print('');

    // Cleanup
    await database.close();
    if (testDir.existsSync()) {
      await testDir.delete(recursive: true);
    }
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  FRAME ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════

/// Computes and emits percentile frame timing statistics.
///
/// Frame budget at 60fps = 16.67ms. Anything above is a jank frame.
/// Frames > 33.33ms (2x budget) are "severe jank" — visually obvious.
void _emitFrameReport(String prefix, List<FrameTiming> timings) {
  if (timings.isEmpty) {
    print(
      'METRIC: ${'${prefix}_FRAME_COUNT'.padRight(55)}=          0',
    );
    print('  (No frames captured — screen may not have rendered.)');
    return;
  }

  // Total frame duration = totalSpan (vsyncStart → rasterFinish)
  final durationsMs = timings
      .map((t) => t.totalSpan.inMicroseconds / 1000.0)
      .toList()
    ..sort();

  final count = durationsMs.length;
  final p50 = durationsMs[(count * 0.50).floor()];
  final p95 = durationsMs[(count * 0.95).floor()];
  final maxFrame = durationsMs.last;
  final mean = durationsMs.reduce((a, b) => a + b) / count;

  const jankBudget = 16.67; // ms for 60fps
  const severeJankBudget = 33.33; // 2x budget

  final jankCount = durationsMs.where((d) => d > jankBudget).length;
  final severeJankCount =
      durationsMs.where((d) => d > severeJankBudget).length;
  final jankPercent = (jankCount / count * 100).toStringAsFixed(1);

  void emit(String name, double value) {
    final paddedName = '${prefix}_$name'.padRight(55);
    final paddedValue = value.toStringAsFixed(2).padLeft(10);
    print('METRIC: $paddedName= $paddedValue ms');
  }

  void emitInt(String name, int value) {
    final paddedName = '${prefix}_$name'.padRight(55);
    final paddedValue = value.toString().padLeft(10);
    print('METRIC: $paddedName= $paddedValue');
  }

  emitInt('FRAME_COUNT', count);
  emit('P50', p50);
  emit('P95', p95);
  emit('MAX_FRAME', maxFrame);
  emit('MEAN', mean);
  emitInt('JANK_COUNT', jankCount);
  emitInt('SEVERE_JANK_COUNT', severeJankCount);
  print(
    '  ($jankPercent% jank rate — '
    '$jankCount/$count frames > ${jankBudget}ms)',
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  NAVIGATION HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Scrolls [finder] into view, then taps its first match.
///
/// Returns false when the finder is empty (caller should SKIP that phase).
Future<bool> _tapWhenVisible(
  WidgetTester tester,
  Finder finder, {
  Duration settleAfter = const Duration(seconds: 2),
}) async {
  if (finder.evaluate().isEmpty) {
    return false;
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle(settleAfter);
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  DATA GENERATORS
// ═══════════════════════════════════════════════════════════════════════════

String _arabicName(Random random) {
  const firstNames = [
    'محمد', 'أحمد', 'عبدالله', 'علي', 'خالد', 'عمر', 'يوسف', 'إبراهيم',
    'سعيد', 'حسن', 'فهد', 'سلطان', 'عبدالرحمن', 'ناصر', 'مصطفى',
    'سامي', 'طارق', 'وليد', 'فيصل', 'ماجد',
  ];
  const lastNames = [
    'الشرعبي', 'المقطري', 'الأحمدي', 'العمري', 'القحطاني',
    'السعدي', 'الزبيدي', 'المالكي', 'الشهراني', 'الحربي',
    'الغامدي', 'العنزي', 'المطيري', 'الدوسري', 'الشمري',
  ];
  return '${firstNames[random.nextInt(firstNames.length)]} '
      '${lastNames[random.nextInt(lastNames.length)]}';
}

String _arabicItem(Random random) {
  const items = [
    'سكر', 'أرز', 'دقيق', 'زيت', 'شاي', 'قهوة', 'حليب', 'ملح',
    'طماطم', 'بصل', 'ثوم', 'بيض', 'جبن', 'خبز', 'لحم', 'دجاج',
  ];
  return items[random.nextInt(items.length)];
}
