import 'dart:io';
import 'dart:typed_data';

import 'package:daftar/application/merchant/resolve_pdf_merchant_profile_use_case.dart';
import 'package:daftar/application/merchant/update_merchant_profile_use_case.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/merchant_profile_local_ds.dart';
import 'package:daftar/data/repositories/merchant_profile_repository_impl.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late MerchantProfileLocalDs merchantLocalDs;
  late Directory tempDir;
  late MerchantProfileRepositoryImpl merchantRepo;
  late MockActivationRepository activationRepository;
  late UpdateMerchantProfileUseCase updateProfile;
  late ResolvePdfMerchantProfileUseCase resolvePdf;
  late AppLocalizations l10n;
  late Uint8List cairoRegularFontBytes;
  late Uint8List cairoBoldFontBytes;
  late Uint8List interRegularFontBytes;
  late Uint8List interBoldFontBytes;

  final now = DateTime.utc(2026, 6, 17, 12);

  setUpAll(() async {
    registerFallbackValue(FeatureFlag.brandedPdf);
    await initializeDateFormatting('en');
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    cairoRegularFontBytes = await File(
      'assets/fonts/Cairo-Regular.ttf',
    ).readAsBytes();
    cairoBoldFontBytes = await File(
      'assets/fonts/Cairo-Bold.ttf',
    ).readAsBytes();
    interRegularFontBytes = await File(
      'assets/fonts/Inter-Regular.ttf',
    ).readAsBytes();
    interBoldFontBytes = await File(
      'assets/fonts/Inter-Bold.ttf',
    ).readAsBytes();
  });

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    merchantLocalDs = MerchantProfileLocalDs(database);
    tempDir = await Directory.systemTemp.createTemp('daftar_merchant_test');
    merchantRepo = MerchantProfileRepositoryImpl(
      merchantProfileLocalDs: merchantLocalDs,
      documentsDirectoryResolver: () async => tempDir,
    );
    activationRepository = MockActivationRepository();
    updateProfile = UpdateMerchantProfileUseCase(merchantRepo);
    resolvePdf = ResolvePdfMerchantProfileUseCase(
      merchantRepo,
      activationRepository,
    );

    final profileId = UuidUtil.generate();
    await merchantLocalDs.upsertProfile(
      db.MerchantProfilesCompanion.insert(
        id: profileId,
        storeName: 'Initial',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('merchant branding integration', () {
    test('persists store name on free tier without unlocking branded PDF', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => false);

      final updateResult = await updateProfile.execute(storeName: 'متجر');
      expect(updateResult.isRight(), isTrue);

      final pdfProfile = await resolvePdf.execute();
      expect(pdfProfile, isNull);

      final row = await merchantLocalDs.getProfile();
      expect(row?.storeName, 'متجر');
    });

    test('updates profile on Pro tier and renders branded PDF', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => true);

      final updateResult = await updateProfile.execute(
        storeName: 'بقالة النور',
        storePhone: '+967771234567',
      );
      expect(updateResult.isRight(), isTrue);

      final brandedProfile = await resolvePdf.execute();
      expect(brandedProfile, isNotNull);
      expect(brandedProfile!.storeName, 'بقالة النور');

      final contact = Contact(
        id: 'contact-branding',
        ledgerId: 'ledger-1',
        name: 'عميل الاختبار',
        avatarColor: '#123456',
        createdAt: now,
        updatedAt: now,
      );
      final balance = ContactBalance(
        contactId: contact.id,
        currencyCode: 'YER',
        totalDebt: 150_000,
        totalPayment: 50_000,
        netBalance: 100_000,
        lastUpdatedAt: now,
      );
      final transactions = [
        Transaction(
          id: 'tx-1',
          contactId: contact.id,
          type: TransactionType.debt,
          amount: 150_000,
          currency: 'YER',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
          description: 'بضاعة',
        ),
      ];

      final bytes = await PdfGenerator.generateContactStatement(
        contact: contact,
        contactBalance: balance,
        transactions: transactions,
        isRtl: true,
        applicationName: l10n.appTitle,
        labelStatement: l10n.statement,
        labelContactName: l10n.name,
        labelGeneratedOn: l10n.generatedOn,
        labelTotalDebt: l10n.totalDebt,
        labelTotalPayment: l10n.totalPayment,
        labelNetBalance: l10n.netBalance,
        labelDate: l10n.date,
        labelDetails: l10n.statementDetails,
        labelDebt: l10n.debt,
        labelPayment: l10n.payment,
        labelRunningBalance: l10n.runningBalance,
        labelCurrency: l10n.currency,
        labelPage: l10n.page,
        msgPreparing: l10n.pdfPreparingData,
        msgGrouping: l10n.pdfGroupingTransactions,
        msgBuilding: l10n.pdfBuildingLayout,
        msgRendering: l10n.pdfRendering,
        merchantProfile: brandedProfile,
        cairoRegularFontBytes: cairoRegularFontBytes,
        cairoBoldFontBytes: cairoBoldFontBytes,
        interRegularFontBytes: interRegularFontBytes,
        interBoldFontBytes: interBoldFontBytes,
      );

      expect(bytes.sublist(0, 5), equals(<int>[37, 80, 68, 70, 45]));
    });
  });
}
