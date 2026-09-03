import 'package:daftar/application/agent/get_closing_day_summary_use_case.dart';
import 'package:daftar/application/agent/run_closing_ritual_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/application/contact/get_collections_candidates_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/calle_device_policy.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGetClosingDaySummaryUseCase extends Mock
    implements GetClosingDaySummaryUseCase {}

class MockUploadDriveBackupUseCase extends Mock
    implements UploadDriveBackupUseCase {}

class MockGetCollectionsCandidatesUseCase extends Mock
    implements GetCollectionsCandidatesUseCase {}

void main() {
  late MockGetClosingDaySummaryUseCase summary;
  late MockUploadDriveBackupUseCase upload;
  late MockGetCollectionsCandidatesUseCase candidates;
  late RunClosingRitualUseCase useCase;

  const day = ClosingDaySummary(
    localDay: '2026-08-15',
    debtCount: 1,
    paymentCount: 0,
    totals: [
      ClosingDayCurrencyTotals(
        currencyCode: 'YER',
        debtMinor: 500,
        paymentMinor: 0,
      ),
    ],
  );

  final metadata = BackupMetadata(
    id: 'backup-1',
    filePath: '/tmp/a.daftar',
    sizeBytes: 12,
    createdAt: DateTime.utc(2026, 8, 15),
    type: BackupType.googleDrive,
    checksum: 'abc',
  );

  const overdue = CollectionsCandidate(
    contactId: 'c1',
    name: 'Ali',
    phone: '+967700000001',
    ledgerId: 'l1',
    netBalance: -400,
    currencyCode: 'YER',
    ageDays: 40,
    toneBand: ReminderToneBand.firm,
  );

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 8, 15));
  });

  setUp(() {
    summary = MockGetClosingDaySummaryUseCase();
    upload = MockUploadDriveBackupUseCase();
    candidates = MockGetCollectionsCandidatesUseCase();
    useCase = RunClosingRitualUseCase(
      getClosingDaySummaryUseCase: summary,
      uploadDriveBackupUseCase: upload,
      getCollectionsCandidatesUseCase: candidates,
    );
    when(
      () => summary.execute(
        localDay: any(named: 'localDay'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => const Right(day));
    when(() => upload.call()).thenAnswer((_) async => Right(metadata));
    when(
      () => candidates.execute(asOf: any(named: 'asOf')),
    ).thenAnswer((_) async => const Right([]));
  });

  test('empty shortlist still uploads backup', () async {
    final result = await useCase.execute(localDay: '2026-08-15');
    final ritual = result.getRight().toNullable()!;

    expect(ritual.summary, day);
    expect(ritual.backupStatus, ClosingBackupStatus.uploaded);
    expect(ritual.shortlist, isEmpty);
    expect(ritual.needsHuman, isFalse);
    verify(() => upload.call()).called(1);
    verify(() => candidates.execute(asOf: any(named: 'asOf'))).called(1);
  });

  test('Drive network fail is queued and needsHuman', () async {
    when(() => upload.call()).thenAnswer(
      (_) async => const Left(NetworkFailure('offline')),
    );
    when(
      () => candidates.execute(asOf: any(named: 'asOf')),
    ).thenAnswer((_) async => const Right([overdue]));

    final result = await useCase.execute(localDay: '2026-08-15');
    final ritual = result.getRight().toNullable()!;

    expect(ritual.backupStatus, ClosingBackupStatus.queued);
    expect(ritual.needsHuman, isTrue);
    expect(ritual.shortlist, [overdue]);
    verify(() => upload.call()).called(1);
  });

  test('unsigned Drive is skippedUnsigned and still loads shortlist', () async {
    when(
      () => upload.call(),
    ).thenAnswer((_) async => const Left(AuthFailure.notSignedIn));

    final result = await useCase.execute(localDay: '2026-08-15');
    final ritual = result.getRight().toNullable()!;

    expect(ritual.backupStatus, ClosingBackupStatus.skippedUnsigned);
    expect(ritual.needsHuman, isTrue);
    verify(() => candidates.execute(asOf: any(named: 'asOf'))).called(1);
  });

  test('linked account without Drive grant is grantRequired not queued', () async {
    when(() => upload.call()).thenAnswer(
      (_) async => const Left(
        AuthFailure('silent', code: 'silent_sign_in_failed'),
      ),
    );

    final result = await useCase.execute(localDay: '2026-08-15');
    final ritual = result.getRight().toNullable()!;

    expect(ritual.backupStatus, ClosingBackupStatus.grantRequired);
    expect(ritual.needsHuman, isTrue);
    expect(ritual.backupStatus, isNot(ClosingBackupStatus.queued));
  });

  test(
    'does not depend on WhatsApp — backup still runs on empty overdue',
    () async {
      final result = await useCase.execute(localDay: '2026-08-15');

      expect(result.isRight(), isTrue);
      verify(() => upload.call()).called(1);
      verifyNever(() => upload.resumeFromEncryptedFilePath(any()));
    },
  );

  test('forwards device policy into collections candidates', () async {
    const policy = CalleDevicePolicy(
      allowDial: true,
      allowlist: {'+15555550100'},
      allowlistRegion: 'US',
    );
    when(
      () => candidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: policy.allowlist,
        allowlistRegion: policy.allowlistRegion,
        allowDial: policy.allowDial,
      ),
    ).thenAnswer((_) async => const Right([]));

    await useCase.execute(
      localDay: '2026-08-15',
      devicePolicy: policy,
    );

    verify(
      () => candidates.execute(
        asOf: any(named: 'asOf'),
        allowlist: policy.allowlist,
        allowlistRegion: policy.allowlistRegion,
        allowDial: policy.allowDial,
      ),
    ).called(1);
  });
}
