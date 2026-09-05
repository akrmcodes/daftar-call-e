import 'package:daftar/application/agent/build_collections_desk_use_case.dart';
import 'package:daftar/application/agent/compose_collections_reminder_draft_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockMerchantProfileRepository extends Mock
    implements MerchantProfileRepository {}

void main() {
  late MockSettingsRepository settings;
  late MockMerchantProfileRepository merchant;
  late BuildCollectionsDeskUseCase useCase;

  setUp(() {
    settings = MockSettingsRepository();
    merchant = MockMerchantProfileRepository();
    useCase = BuildCollectionsDeskUseCase(
      settingsRepository: settings,
      merchantProfileRepository: merchant,
      composeDraft: const ComposeCollectionsReminderDraftUseCase(),
    );
    when(() => settings.get()).thenAnswer(
      (_) async => const Right(AppSettings(locale: 'en')),
    );
    when(() => merchant.get()).thenAnswer((_) async => const Right(null));
  });

  CollectionsCandidate candidate({
    required String id,
    required int ageDays,
    required ReminderToneBand tone,
    int owedMinor = 1500,
    OutreachRail rail = OutreachRail.email,
    String? email = 'test@example.com',
    String? phone,
  }) {
    return CollectionsCandidate(
      contactId: id,
      name: 'n$id',
      phone: phone ?? '+9677000000$id',
      email: email,
      ledgerId: 'ledger',
      netBalance: -owedMinor,
      currencyCode: 'YER',
      ageDays: ageDays,
      toneBand: tone,
      rail: rail,
    );
  }

  ClosingRitualResult ritual({
    required List<CollectionsCandidate> shortlist,
    required ClosingReminderPolicy reminders,
    required ClosingPdfPolicy pdfs,
  }) {
    return ClosingRitualResult(
      summary: const ClosingDaySummary(
        localDay: '2026-08-15',
        debtCount: 0,
        paymentCount: 0,
        totals: [],
      ),
      backupStatus: ClosingBackupStatus.uploaded,
      shortlist: shortlist,
    ).withReminderPolicy(reminders).withPdfPolicy(pdfs);
  }

  test('empty shortlist is Right empty without reading settings', () async {
    final result = await useCase.execute(
      ritual(
        shortlist: [],
        reminders: ClosingReminderPolicy.none,
        pdfs: ClosingPdfPolicy.none,
      ),
    );

    expect(result.getRight().toNullable()?.rows, isEmpty);
    verifyNever(() => settings.get());
    verifyNever(() => merchant.get());
  });

  test('full shortlist yields one row per candidate', () async {
    final shortlist = [
      for (var i = 0; i < 7; i++)
        candidate(
          id: '$i',
          ageDays: i < 2 ? 40 : 3,
          tone: i < 2 ? ReminderToneBand.firm : ReminderToneBand.friendly,
        ),
    ];

    final result = await useCase.execute(
      ritual(
        shortlist: shortlist,
        reminders: ClosingReminderPolicy.top5,
        pdfs: ClosingPdfPolicy.none,
      ),
    );
    final built = result.getRight().toNullable()!;

    expect(built.rows, hasLength(7));
    expect(built.locale, 'en');
    expect(built.storeName, 'Daftar');
    expect(built.rows.first.body, contains('1500'));
    expect(built.rows.first.subject, contains('outstanding balance'));
    expect(built.rows.every((row) => !row.attachPdf), isTrue);
  });

  test('selective PDF seeds attach on firm or ageDays >= 30 only', () async {
    final shortlist = [
      candidate(id: 'firm', ageDays: 40, tone: ReminderToneBand.firm),
      candidate(id: 'mid', ageDays: 12, tone: ReminderToneBand.reminder),
      candidate(id: 'new', ageDays: 2, tone: ReminderToneBand.friendly),
    ];

    final result = await useCase.execute(
      ritual(
        shortlist: shortlist,
        reminders: ClosingReminderPolicy.all,
        pdfs: ClosingPdfPolicy.selective,
      ),
    );
    final rows = result.getRight().toNullable()!.rows;

    expect(rows, hasLength(3));
    expect(
      rows.firstWhere((row) => row.candidate.contactId == 'firm').attachPdf,
      isTrue,
    );
    expect(
      rows.firstWhere((row) => row.candidate.contactId == 'mid').attachPdf,
      isFalse,
    );
    expect(
      rows.firstWhere((row) => row.candidate.contactId == 'new').attachPdf,
      isFalse,
    );
  });

  test('rankedTop5 attaches PDF on first five of the send set', () async {
    final shortlist = [
      for (var i = 0; i < 8; i++)
        candidate(
          id: '$i',
          ageDays: 12,
          tone: ReminderToneBand.reminder,
        ),
    ];
    final result = await useCase.execute(
      ritual(
        shortlist: shortlist,
        reminders: ClosingReminderPolicy.all,
        pdfs: ClosingPdfPolicy.rankedTop5,
      ),
    );
    final rows = result.getRight().toNullable()!.rows;
    expect(rows, hasLength(8));
    expect(rows.take(5).every((row) => row.attachPdf), isTrue);
    expect(rows.skip(5).every((row) => !row.attachPdf), isTrue);
  });

  test('uses merchant store name when present', () async {
    when(() => merchant.get()).thenAnswer(
      (_) async => Right(
        MerchantProfile(
          id: 'p1',
          storeName: 'Khazna Shop',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
    );

    final result = await useCase.execute(
      ritual(
        shortlist: [
          candidate(id: 'a', ageDays: 3, tone: ReminderToneBand.friendly),
        ],
        reminders: ClosingReminderPolicy.all,
        pdfs: ClosingPdfPolicy.none,
      ),
    );

    expect(result.getRight().toNullable()?.storeName, 'Khazna Shop');
    expect(result.getRight().toNullable()?.rows.single.body, contains('Khazna Shop'));
  });

  test('settings failure still builds with Arabic fallback', () async {
    when(() => settings.get()).thenAnswer(
      (_) async => const Left(DatabaseFailure('missing')),
    );

    final result = await useCase.execute(
      ritual(
        shortlist: [
          candidate(id: 'a', ageDays: 3, tone: ReminderToneBand.friendly),
        ],
        reminders: ClosingReminderPolicy.all,
        pdfs: ClosingPdfPolicy.none,
      ),
    );

    expect(result.getRight().toNullable()?.locale, 'ar');
    expect(result.getRight().toNullable()?.rows, hasLength(1));
  });

  test('dual rail: US both has C.3, YE callUnavailable has C.2 only', () async {
    const usPhone = '+15555550100';
    final shortlist = [
      candidate(
        id: 'us',
        ageDays: 40,
        tone: ReminderToneBand.firm,
        rail: OutreachRail.both,
        email: 'us@example.com',
        phone: usPhone,
      ),
      candidate(
        id: 'ye',
        ageDays: 20,
        tone: ReminderToneBand.reminder,
        rail: OutreachRail.callUnavailable,
        email: 'ye@example.com',
        phone: '0771234567',
        owedMinor: 1000,
      ),
    ];

    final result = await useCase.execute(
      ritual(
        shortlist: shortlist,
        reminders: ClosingReminderPolicy.all,
        pdfs: ClosingPdfPolicy.none,
      ),
    );
    final rows = result.getRight().toNullable()!.rows;

    expect(rows, hasLength(2));

    final usRow = rows.firstWhere((row) => row.candidate.contactId == 'us');
    final yeRow = rows.firstWhere((row) => row.candidate.contactId == 'ye');

    expect(usRow.callTask, isNotEmpty);
    expect(usRow.callTask, contains('Call nus on behalf of'));
    expect(usRow.body, isNotEmpty);
    expect(yeRow.callTask, isEmpty);
    expect(yeRow.body, contains('nye'));
  });

  test('credit-limit trigger appends hold sentence to call task', () async {
    final shortlist = [
      candidate(
        id: 'us',
        ageDays: 40,
        tone: ReminderToneBand.firm,
        rail: OutreachRail.call,
        phone: '+15555550100',
      ),
    ];

    final result = await useCase.execute(
      ritual(
        shortlist: shortlist,
        reminders: ClosingReminderPolicy.none,
        pdfs: ClosingPdfPolicy.none,
      ),
      trigger: CallBatchTrigger.creditLimit,
    );
    final row = result.getRight().toNullable()!.rows.single;

    expect(row.callTask, contains('new goods are on hold'));
    expect(row.callTask, contains('acknowledged_hold'));
  });
}
