import 'dart:io';
import 'dart:typed_data';

import 'package:daftar/application/merchant/resolve_pdf_merchant_profile_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockActivationRepository extends Mock implements ActivationRepository {}

class MockMerchantProfileRepository extends Mock
    implements MerchantProfileRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockActivationRepository activationRepository;
  late MockMerchantProfileRepository merchantProfileRepository;
  late ResolvePdfMerchantProfileUseCase sut;
  late AppLocalizations l10n;
  late Uint8List cairoRegularFontBytes;
  late Uint8List cairoBoldFontBytes;
  late Uint8List interRegularFontBytes;
  late Uint8List interBoldFontBytes;

  final now = DateTime.utc(2026, 5, 30, 12);
  final brandedProfile = MerchantProfile(
    id: 'merchant-1',
    storeName: 'بقالة النور',
    storePhone: '+967712345678',
    createdAt: now,
    updatedAt: now,
  );

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

  setUp(() {
    activationRepository = MockActivationRepository();
    merchantProfileRepository = MockMerchantProfileRepository();
    sut = ResolvePdfMerchantProfileUseCase(
      merchantProfileRepository,
      activationRepository,
    );
  });

  group('ResolvePdfMerchantProfileUseCase', () {
    test(
      'returns null for free tier without reading merchant profile',
      () async {
        when(
          () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
        ).thenAnswer((_) async => false);

        final result = await sut.execute();

        expect(result, isNull);
        verify(
          () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
        ).called(1);
        verifyNever(() => merchantProfileRepository.get());
      },
    );

    test('returns null for Pro tier when stored profile has empty store name', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => true);
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => Right(
          brandedProfile.copyWith(storeName: '   '),
        ),
      );

      final result = await sut.execute();

      expect(result, isNull);
      verify(() => merchantProfileRepository.get()).called(1);
    });

    test('returns merchant profile for Pro+ tier with brandedPdf unlocked', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => true);
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => Right(brandedProfile),
      );

      final result = await sut.execute();

      expect(result, brandedProfile);
      verify(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).called(1);
      verify(() => merchantProfileRepository.get()).called(1);
    });

    test('returns null when profile repository fails', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.brandedPdf),
      ).thenAnswer((_) async => true);
      when(() => merchantProfileRepository.get()).thenAnswer(
        (_) async => const Left(DatabaseFailure('read failed')),
      );

      final result = await sut.execute();

      expect(result, isNull);
    });
  });

  group('PdfGenerator.generateContactStatement branding execution', () {
    late Contact contact;
    late ContactBalance balance;
    late List<Transaction> transactions;

    setUp(() {
      contact = Contact(
        id: 'contact-branding',
        ledgerId: 'ledger-1',
        name: 'عميل الاختبار',
        avatarColor: '#123456',
        createdAt: now,
        updatedAt: now,
      );
      balance = ContactBalance(
        contactId: contact.id,
        currencyCode: 'YER',
        totalDebt: 150_000,
        totalPayment: 50_000,
        netBalance: 100_000,
        lastUpdatedAt: now,
      );
      transactions = [
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
    });

    Future<Uint8List> generateStatement({MerchantProfile? merchantProfile}) {
      return PdfGenerator.generateContactStatement(
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
        merchantProfile: merchantProfile,
        cairoRegularFontBytes: cairoRegularFontBytes,
        cairoBoldFontBytes: cairoBoldFontBytes,
        interRegularFontBytes: interRegularFontBytes,
        interBoldFontBytes: interBoldFontBytes,
      );
    }

    test('renders unbranded PDF when merchantProfile is null', () async {
      final bytes = await generateStatement();

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(0));
      expect(bytes.sublist(0, 5), equals(<int>[37, 80, 68, 70, 45]));
    });

    test('renders branded PDF when merchantProfile is provided', () async {
      final bytes = await generateStatement(merchantProfile: brandedProfile);

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(0));
      expect(bytes.sublist(0, 5), equals(<int>[37, 80, 68, 70, 45]));
    });
  });
}
