import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late Uint8List cairoRegularFontBytes;
  late Uint8List cairoBoldFontBytes;
  late Uint8List interRegularFontBytes;
  late Uint8List interBoldFontBytes;

  setUpAll(() async {
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

  test(
    'builds the flattened isolate payload and renders 500 transactions without TooManyPagesException',
    () async {
      const contactId = 'contact-1';
      final now = DateTime.now().toUtc();
      final contact = _buildStressContact(now);
      final contactBalance = _buildStressBalance(contactId, now);
      final payloadProbePort = ReceivePort();
      addTearDown(payloadProbePort.close);

      final payloadProbe = await PdfGenerator.buildIsolatePayload(
        sendPort: payloadProbePort.sendPort,
        contact: contact,
        contactBalance: contactBalance,
        transactions: _buildStressTransactions(
          contactId: contactId,
          now: now,
          count: 2,
          longDescription: false,
        ),
        isRtl: false,
        applicationName: 'Daftar QA',
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
        cairoRegularFontBytes: cairoRegularFontBytes,
        cairoBoldFontBytes: cairoBoldFontBytes,
        interRegularFontBytes: interRegularFontBytes,
        interBoldFontBytes: interBoldFontBytes,
        generatedOnValue: '07 May 2026',
      );

      expect(
        payloadProbe.keys,
        containsAll(<String>{
          'sendPort',
          'localeTag',
          'request',
          'regularFontTransferable',
          'boldFontTransferable',
          'fallbackRegularFontTransferable',
          'fallbackBoldFontTransferable',
        }),
      );
      expect(payloadProbe['sendPort'], same(payloadProbePort.sendPort));
      expect(payloadProbe['localeTag'], 'en');
      expect(_isSendablePayloadValue(payloadProbe), isTrue);

      final request = payloadProbe['request']! as Map<String, Object?>;
      expect(
        <String>{
          'labelDate',
          'labelDetails',
          'labelDebt',
          'labelPayment',
          'labelRunningBalance',
          'statementPeriodText',
        }.every(request.containsKey),
        isTrue,
      );
      expect(request['statementPeriodText'], '');
      final requestTransactions = request['transactions']! as List<Object?>;
      expect(requestTransactions, hasLength(2));
      final firstTransaction =
          requestTransactions.first! as Map<String, Object?>;
      expect(firstTransaction['transactionDate'], isA<String>());
      expect(firstTransaction['createdAt'], isA<String>());
      expect(firstTransaction['type'], isA<String>());

      final transactions = _buildStressTransactions(
        contactId: contactId,
        now: now,
        count: 500,
        longDescription: false,
      );

      final contactBalanceForRender = _buildStressBalance(contactId, now);

      final progressUpdates = <double>[];
      final progressMessages = <String>[];

      final stopwatch = Stopwatch()..start();
      final bytes = await PdfGenerator.generateContactStatement(
        contact: contact,
        contactBalance: contactBalanceForRender,
        transactions: transactions,
        isRtl: false,
        applicationName: 'Daftar QA',
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
        cairoRegularFontBytes: cairoRegularFontBytes,
        cairoBoldFontBytes: cairoBoldFontBytes,
        interRegularFontBytes: interRegularFontBytes,
        interBoldFontBytes: interBoldFontBytes,
        onProgress: (progress, message) {
          progressUpdates.add(progress);
          progressMessages.add(message);
        },
      );

      stopwatch.stop();
      expect(stopwatch.elapsed.inSeconds, lessThan(8));

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(5));
      expect(bytes.sublist(0, 5), equals(<int>[37, 80, 68, 70, 45]));

      expect(progressUpdates, isNotEmpty);
      expect(progressMessages, isNotEmpty);
      expect(progressUpdates.toSet().length, greaterThan(1));
      expect(progressUpdates.any((value) => value >= 0.9), isTrue);
    },
  );

  test(
    'defers bidi sanitization to isolate and still renders valid PDF',
    () async {
      final dirtyPort = ReceivePort();
      addTearDown(dirtyPort.close);

      final dirtyContact = Contact(
        id: 'contact-rtl',
        ledgerId: 'ledger-1',
        name: 'Al\u200Fi\u00A0Khan',
        avatarColor: '#123456',
        createdAt: DateTime.utc(2026, 5, 7),
        updatedAt: DateTime.utc(2026, 5, 7),
      );
      final dirtyBalance = ContactBalance(
        contactId: 'contact-rtl',
        currencyCode: '\u200FUSD\u202F',
        totalDebt: 1500,
        totalPayment: 500,
        netBalance: -1000,
        lastUpdatedAt: DateTime.utc(2026, 5, 7),
      );
      final dirtyTransactions = <Transaction>[
        Transaction(
          id: 'tx-rtl-1',
          contactId: 'contact-rtl',
          type: TransactionType.debt,
          amount: 1500,
          currency: '\u200FUSD\u00A0',
          transactionDate: DateTime.utc(2026, 5, 6),
          createdAt: DateTime.utc(2026, 5, 7),
          updatedAt: DateTime.utc(2026, 5, 7),
          description: 'Invoice\u200F\u00A0#42',
        ),
      ];

      final dirtyPayload = await PdfGenerator.buildIsolatePayload(
        sendPort: dirtyPort.sendPort,
        contact: dirtyContact,
        contactBalance: dirtyBalance,
        transactions: dirtyTransactions,
        isRtl: true,
        applicationName: 'Da\u200Fftar\u00A0QA',
        labelStatement: 'State\u200Fment',
        labelContactName: 'Na\u200Fme',
        labelGeneratedOn: 'Gene\u00A0rated',
        labelTotalDebt: 'Total\u200FDebt',
        labelTotalPayment: 'Total\u00A0Payment',
        labelNetBalance: 'Net\u200FBalance',
        labelDate: 'Da\u00A0te',
        labelDetails: 'De\u200Ftails',
        labelDebt: 'De\u200Fbt',
        labelPayment: 'Pay\u00A0ment',
        labelRunningBalance: 'Run\u200Fning',
        labelCurrency: 'Cur\u00A0rency',
        labelPage: 'Pa\u200Fge',
        msgPreparing: 'Pre\u200Fparing',
        msgGrouping: 'Gro\u00A0uping',
        msgBuilding: 'Buil\u200Fding',
        msgRendering: 'Ren\u00A0dering',
        cairoRegularFontBytes: cairoRegularFontBytes,
        cairoBoldFontBytes: cairoBoldFontBytes,
        interRegularFontBytes: interRegularFontBytes,
        interBoldFontBytes: interBoldFontBytes,
        generatedOnValue: '07\u200F May\u00A02026',
      );

      final request = _asMap(dirtyPayload['request']);
      expect(
        _containsProblematicPdfUnicode(
          _stringValue(request, 'applicationName'),
        ),
        isTrue,
      );
      expect(
        _containsProblematicPdfUnicode(_stringValue(request, 'titleStatement')),
        isTrue,
      );
      expect(
        _containsProblematicPdfUnicode(_stringValue(request, 'labelDetails')),
        isTrue,
      );
      expect(
        _containsProblematicPdfUnicode(_stringValue(request, 'contactName')),
        isTrue,
      );

      final transactions = _asList(request['transactions']);
      final transaction = _asMap(transactions.single);
      expect(transaction['currency'], '\u200FUSD\u00A0');
      expect(transaction['description'], 'Invoice\u200F\u00A0#42');
      expect(transaction['itemName'], isNull);

      final bytes = await PdfGenerator.generateContactStatement(
        contact: dirtyContact,
        contactBalance: dirtyBalance,
        transactions: dirtyTransactions,
        isRtl: true,
        applicationName: 'Da\u200Fftar\u00A0QA',
        labelStatement: 'State\u200Fment',
        labelContactName: 'Na\u200Fme',
        labelGeneratedOn: 'Gene\u00A0rated',
        labelTotalDebt: 'Total\u200FDebt',
        labelTotalPayment: 'Total\u00A0Payment',
        labelNetBalance: 'Net\u200FBalance',
        labelDate: 'Da\u00A0te',
        labelDetails: 'De\u200Ftails',
        labelDebt: 'De\u200Fbt',
        labelPayment: 'Pay\u00A0ment',
        labelRunningBalance: 'Run\u200Fning',
        labelCurrency: 'Cur\u00A0rency',
        labelPage: 'Pa\u200Fge',
        msgPreparing: 'Pre\u200Fparing',
        msgGrouping: 'Gro\u00A0uping',
        msgBuilding: 'Buil\u200Fding',
        msgRendering: 'Ren\u00A0dering',
        cairoRegularFontBytes: cairoRegularFontBytes,
        cairoBoldFontBytes: cairoBoldFontBytes,
        interRegularFontBytes: interRegularFontBytes,
        interBoldFontBytes: interBoldFontBytes,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 5), equals(<int>[37, 80, 68, 70, 45]));
    },
  );
}

Contact _buildStressContact(DateTime now) {
  return Contact(
    id: 'contact-1',
    ledgerId: 'ledger-1',
    name: 'Stress Test Contact',
    avatarColor: '#123456',
    createdAt: now,
    updatedAt: now,
  );
}

ContactBalance _buildStressBalance(String contactId, DateTime now) {
  return ContactBalance(
    contactId: contactId,
    currencyCode: 'USD',
    totalDebt: 0,
    totalPayment: 0,
    netBalance: 0,
    lastUpdatedAt: now,
  );
}

List<Transaction> _buildStressTransactions({
  required String contactId,
  required DateTime now,
  required int count,
  required bool longDescription,
}) {
  return List<Transaction>.generate(count, (index) {
    final type = index.isEven ? TransactionType.debt : TransactionType.payment;
    final description = longDescription
        ? 'Enterprise-scale stress transaction ${index.toString().padLeft(4, '0')} with an intentionally verbose description to force wrapping and multi-page pagination in the PDF table renderer.'
        : 'Transaction $index';

    return Transaction(
      id: 'tx-$index',
      contactId: contactId,
      type: type,
      amount: 100 + (index % 20),
      currency: 'USD',
      transactionDate: now.subtract(Duration(days: count - index)),
      createdAt: now,
      updatedAt: now,
      description: description,
      itemName: 'Item ${index % 7}',
    );
  });
}

bool _isSendablePayloadValue(Object? value) {
  if (value == null ||
      value is String ||
      value is bool ||
      value is int ||
      value is double ||
      value is SendPort ||
      value is Uint8List ||
      value is TransferableTypedData) {
    return true;
  }

  if (value is Map) {
    return value.entries.every(
      (entry) => entry.key is String && _isSendablePayloadValue(entry.value),
    );
  }

  if (value is Iterable) {
    return value.every(_isSendablePayloadValue);
  }

  return false;
}

bool _containsProblematicPdfUnicode(String value) {
  return RegExp(
    r'[\u00A0\u061C\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
  ).hasMatch(value);
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  throw StateError('Expected a map payload value');
}

List<Object?> _asList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }

  throw StateError('Expected a list payload value');
}

String _stringValue(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String) {
    return value;
  }

  throw StateError('Expected "$key" to be a String');
}
