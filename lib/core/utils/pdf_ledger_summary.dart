import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:daftar/application/ledger/ledger_summary_export_data.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/pdf_colors.dart';
import 'package:daftar/core/utils/pdf_premium_layout.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _fontCairoRegular = 'assets/fonts/Cairo-Regular.ttf';
const _fontCairoBold = 'assets/fonts/Cairo-Bold.ttf';
const _fontInterRegular = 'assets/fonts/Inter-Regular.ttf';
const _fontInterBold = 'assets/fonts/Inter-Bold.ttf';

const Duration _generationTimeout = Duration(seconds: 30);

/// Ledger-level PDF summary (contacts + net balances, no transactions).
abstract final class LedgerSummaryPdfGenerator {
  /// Builds a localized ledger summary PDF in a background isolate.
  static Future<Uint8List> generate({
    required LedgerSummaryExportData data,
    required bool isRtl,
    required String applicationName,
    required String labelSummaryTitle,
    required String labelLedgerName,
    required String labelGeneratedOn,
    required String labelTotalLedgerBalance,
    required String labelTotalDebt,
    required String labelTotalPayment,
    required String labelNetBalance,
    required String labelRowNumber,
    required String labelName,
    required String labelPhone,
    required String labelCurrency,
    required String labelPage,
    required String msgPreparing,
    required String msgGrouping,
    required String msgBuilding,
    required String msgRendering,
    Uint8List? cairoRegularFontBytes,
    Uint8List? cairoBoldFontBytes,
    Uint8List? interRegularFontBytes,
    Uint8List? interBoldFontBytes,
    void Function(double progress, String message)? onProgress,
    MerchantProfile? merchantProfile,
  }) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final completer = Completer<Uint8List>();
    Isolate? isolate;

    StreamSubscription<dynamic>? receiveSub;
    StreamSubscription<dynamic>? errorSub;
    StreamSubscription<dynamic>? exitSub;

    var cleanedUp = false;
    void cleanup() {
      if (cleanedUp) return;
      cleanedUp = true;
      unawaited(receiveSub?.cancel());
      unawaited(errorSub?.cancel());
      unawaited(exitSub?.cancel());
      receivePort.close();
      errorPort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }

    receiveSub = receivePort.listen((message) {
      if (message is _LedgerProgressMsg) {
        onProgress?.call(message.progress, message.message);
        return;
      }
      if (message is Uint8List) {
        if (!completer.isCompleted) completer.complete(message);
        cleanup();
        return;
      }
      if (message is _LedgerErrorMsg) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(message.error),
            StackTrace.fromString(message.stackTrace),
          );
        }
        cleanup();
      }
    });

    errorSub = errorPort.listen((message) {
      if (completer.isCompleted) return;
      var error = 'Unknown isolate error';
      var stack = '';
      if (message is List && message.length >= 2) {
        error = message[0]?.toString() ?? error;
        stack = message[1]?.toString() ?? '';
      }
      completer.completeError(
        Exception(error),
        StackTrace.fromString(stack),
      );
      cleanup();
    });

    exitSub = exitPort.listen((_) {
      if (completer.isCompleted) return;
      completer.completeError(
        Exception('Ledger summary PDF isolate exited unexpectedly'),
      );
      cleanup();
    });

    final payload = await buildIsolatePayload(
      sendPort: receivePort.sendPort,
      data: data,
      isRtl: isRtl,
      applicationName: applicationName,
      labelSummaryTitle: labelSummaryTitle,
      labelLedgerName: labelLedgerName,
      labelGeneratedOn: labelGeneratedOn,
      labelTotalLedgerBalance: labelTotalLedgerBalance,
      labelTotalDebt: labelTotalDebt,
      labelTotalPayment: labelTotalPayment,
      labelNetBalance: labelNetBalance,
      labelRowNumber: labelRowNumber,
      labelName: labelName,
      labelPhone: labelPhone,
      labelCurrency: labelCurrency,
      labelPage: labelPage,
      msgPreparing: msgPreparing,
      msgGrouping: msgGrouping,
      msgBuilding: msgBuilding,
      msgRendering: msgRendering,
      cairoRegularFontBytes: cairoRegularFontBytes,
      cairoBoldFontBytes: cairoBoldFontBytes,
      interRegularFontBytes: interRegularFontBytes,
      interBoldFontBytes: interBoldFontBytes,
      merchantProfile: merchantProfile,
    );

    try {
      isolate = await Isolate.spawn<Map<String, Object?>>(
        _buildLedgerSummaryPdfIsolate,
        payload,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );
    } on Object catch (error, stackTrace) {
      cleanup();
      return Future<Uint8List>.error(error, stackTrace);
    }

    try {
      return await completer.future.timeout(_generationTimeout);
    } on TimeoutException {
      cleanup();
      throw TimeoutException(
        'Ledger summary PDF exceeded ${_generationTimeout.inSeconds}s',
        _generationTimeout,
      );
    }
  }

  /// Builds the sendable isolate payload (exposed for tests).
  static Future<Map<String, Object?>> buildIsolatePayload({
    required SendPort sendPort,
    required LedgerSummaryExportData data,
    required bool isRtl,
    required String applicationName,
    required String labelSummaryTitle,
    required String labelLedgerName,
    required String labelGeneratedOn,
    required String labelTotalLedgerBalance,
    required String labelTotalDebt,
    required String labelTotalPayment,
    required String labelNetBalance,
    required String labelRowNumber,
    required String labelName,
    required String labelPhone,
    required String labelCurrency,
    required String labelPage,
    required String msgPreparing,
    required String msgGrouping,
    required String msgBuilding,
    required String msgRendering,
    Uint8List? cairoRegularFontBytes,
    Uint8List? cairoBoldFontBytes,
    Uint8List? interRegularFontBytes,
    Uint8List? interBoldFontBytes,
    String? generatedOnValue,
    MerchantProfile? merchantProfile,
  }) async {
    final localeTag = isRtl ? 'ar' : 'en';

    final hasFontOverrides =
        cairoRegularFontBytes != null &&
        cairoBoldFontBytes != null &&
        interRegularFontBytes != null &&
        interBoldFontBytes != null;

    final fonts = hasFontOverrides
        ? _LedgerFontBundle(
            cairoRegular: cairoRegularFontBytes,
            cairoBold: cairoBoldFontBytes,
            interRegular: interRegularFontBytes,
            interBold: interBoldFontBytes,
          )
        : await _LedgerFontCache.instance.load();

    final effectiveGeneratedOnValue =
        generatedOnValue ??
        await (() async {
          await initializeDateFormatting(localeTag);
          return DateFormat.yMMMd(AppConstants.numeralLocale).format(DateTime.now());
        })();

    final brandingProfile = merchantProfile != null &&
            merchantProfile.storeName.trim().isNotEmpty
        ? merchantProfile
        : null;

    Uint8List? merchantLogoBytes;
    final logoPath = brandingProfile?.logoPath?.trim();
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final logoFile = File(logoPath);
        if (logoFile.existsSync()) {
          merchantLogoBytes = await logoFile.readAsBytes();
        }
      } on Object {
        merchantLogoBytes = null;
      }
    }

    final requestMap = <String, Object?>{
      'applicationName': applicationName,
      'localeTag': localeTag,
      'isRtl': isRtl,
      'titleSummary': labelSummaryTitle,
      'labelLedgerName': labelLedgerName,
      'labelGeneratedOn': labelGeneratedOn,
      'labelTotalLedgerBalance': labelTotalLedgerBalance,
      'labelTotalDebt': labelTotalDebt,
      'labelTotalPayment': labelTotalPayment,
      'labelNetBalance': labelNetBalance,
      'labelRowNumber': labelRowNumber,
      'labelName': labelName,
      'labelPhone': labelPhone,
      'labelCurrency': labelCurrency,
      'labelPage': labelPage,
      'ledgerName': data.ledgerName,
      'generatedOnValue': effectiveGeneratedOnValue,
      'contacts': data.contacts
          .map(
            (row) => <String, Object?>{
              'name': row.name,
              'phone': row.phone,
              'netBalance': row.netBalance,
              'currencyCode': row.currencyCode,
            },
          )
          .toList(growable: false),
      'ledgerTotals': data.ledgerTotals
          .map(
            (total) => <String, Object?>{
              'currencyCode': total.currencyCode,
              'totalDebt': total.totalDebt,
              'totalPayment': total.totalPayment,
              'netBalance': total.netBalance,
            },
          )
          .toList(growable: false),
      'msgPreparing': msgPreparing,
      'msgGrouping': msgGrouping,
      'msgBuilding': msgBuilding,
      'msgRendering': msgRendering,
      'merchantStoreName': brandingProfile?.storeName,
      'merchantStorePhone': brandingProfile?.storePhone,
      'merchantLogoBytes': merchantLogoBytes,
    };

    return <String, Object?>{
      'sendPort': sendPort,
      'localeTag': localeTag,
      'regularFontTransferable': TransferableTypedData.fromList(
        <Uint8List>[fonts.cairoRegular],
      ),
      'boldFontTransferable': TransferableTypedData.fromList(
        <Uint8List>[fonts.cairoBold],
      ),
      'fallbackRegularFontTransferable': TransferableTypedData.fromList(
        <Uint8List>[fonts.interRegular],
      ),
      'fallbackBoldFontTransferable': TransferableTypedData.fromList(
        <Uint8List>[fonts.interBold],
      ),
      'request': requestMap,
    };
  }
}

final class _LedgerFontCache {
  _LedgerFontCache._();

  static final _LedgerFontCache instance = _LedgerFontCache._();

  Future<_LedgerFontBundle>? _loading;

  Future<_LedgerFontBundle> load() {
    return _loading ??= _loadOnce();
  }

  Future<_LedgerFontBundle> _loadOnce() async {
    final results = await Future.wait<ByteData>(<Future<ByteData>>[
      rootBundle.load(_fontCairoRegular),
      rootBundle.load(_fontCairoBold),
      rootBundle.load(_fontInterRegular),
      rootBundle.load(_fontInterBold),
    ]);

    Uint8List slice(ByteData data) =>
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    return _LedgerFontBundle(
      cairoRegular: slice(results[0]),
      cairoBold: slice(results[1]),
      interRegular: slice(results[2]),
      interBold: slice(results[3]),
    );
  }
}

final class _LedgerFontBundle {
  const _LedgerFontBundle({
    required this.cairoRegular,
    required this.cairoBold,
    required this.interRegular,
    required this.interBold,
  });

  final Uint8List cairoRegular;
  final Uint8List cairoBold;
  final Uint8List interRegular;
  final Uint8List interBold;
}

Future<void> _buildLedgerSummaryPdfIsolate(Map<String, Object?> payload) async {
  final sendPort = _ledgerRequiredValue<SendPort>(payload, 'sendPort');
  final localeTag = _ledgerRequiredValue<String>(payload, 'localeTag');

  await initializeDateFormatting(localeTag);

  try {
    final requestMap = Map<String, Object?>.from(
      _ledgerRequiredValue<Map<String, Object?>>(payload, 'request'),
    );
    requestMap['regularFontBytes'] = _ledgerMaterializeFontBytes(
      payload['regularFontTransferable'],
    );
    requestMap['boldFontBytes'] = _ledgerMaterializeFontBytes(
      payload['boldFontTransferable'],
    );
    requestMap['fallbackRegularFontBytes'] = _ledgerMaterializeFontBytes(
      payload['fallbackRegularFontTransferable'],
    );
    requestMap['fallbackBoldFontBytes'] = _ledgerMaterializeFontBytes(
      payload['fallbackBoldFontTransferable'],
    );
    final request = _LedgerSummaryPdfRequest.fromMap(requestMap);
    final bytes = await _buildLedgerSummaryPdfBytes(request, sendPort);
    sendPort.send(bytes);
  } on Object catch (error, stackTrace) {
    sendPort.send(
      _LedgerErrorMsg(error.toString(), stackTrace.toString()),
    );
  }
}

Uint8List _ledgerMaterializeFontBytes(Object? value) {
  if (value is TransferableTypedData) {
    return value.materialize().asUint8List();
  }
  if (value is Uint8List) {
    return value;
  }
  throw const FormatException('Expected TransferableTypedData or Uint8List font');
}

Future<Uint8List> _buildLedgerSummaryPdfBytes(
  _LedgerSummaryPdfRequest req,
  SendPort sendPort,
) async {
  sendPort.send(_LedgerProgressMsg(0.10, req.msgPreparing));

  ByteData asByteData(Uint8List bytes) =>
      ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

  final cairoRegular = pw.Font.ttf(asByteData(req.regularFontBytes));
  final cairoBold = pw.Font.ttf(asByteData(req.boldFontBytes));
  final interRegular = pw.Font.ttf(asByteData(req.fallbackRegularFontBytes));
  final interBold = pw.Font.ttf(asByteData(req.fallbackBoldFontBytes));

  final styles = _LedgerPdfStyles(
    base: cairoRegular,
    bold: cairoBold,
    fallback: <pw.Font>[interRegular, interBold],
  );

  final textDirection = req.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final amountFmt = NumberFormat.decimalPattern(AppConstants.numeralLocale);

  sendPort.send(_LedgerProgressMsg(0.30, req.msgGrouping));
  final sections = _buildLedgerCurrencySections(req, amountFmt);

  sendPort.send(_LedgerProgressMsg(0.65, req.msgBuilding));

  final document = pw.Document()
    ..addPage(
      pw.MultiPage(
        maxPages: 1000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: textDirection,
          theme: pw.ThemeData.withFont(
            base: cairoRegular,
            bold: cairoBold,
            fontFallback: <pw.Font>[interRegular, interBold],
          ),
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        ),
        footer: (context) => pw.Directionality(
          textDirection: textDirection,
          child: _buildLedgerFooter(req, styles, context),
        ),
        build: (context) {
          return <pw.Widget>[
            pw.Directionality(
              textDirection: textDirection,
              child: _buildLedgerSummaryHeader(req, styles, textDirection),
            ),
            ..._buildLedgerBody(req, styles, sections, textDirection),
          ];
        },
      ),
    );

  sendPort.send(_LedgerProgressMsg(0.90, req.msgRendering));
  return document.save();
}

final class _LedgerPdfStyles {
  _LedgerPdfStyles({
    required this.base,
    required this.bold,
    required this.fallback,
  });

  final pw.Font base;
  final pw.Font bold;
  final List<pw.Font> fallback;

  pw.TextStyle text({
    double size = 10,
    PdfColor color = PdfBrandColors.inkPrimary,
    bool emphasize = false,
  }) {
    if (emphasize) {
      return pw.TextStyle(
        font: bold,
        fontFallback: fallback,
        fontSize: size,
        color: color,
        fontWeight: pw.FontWeight.bold,
      );
    }

    return pw.TextStyle(
      font: base,
      fontFallback: fallback,
      fontSize: size,
      color: color,
    );
  }
}

pw.Widget _buildLedgerSummaryHeader(
  _LedgerSummaryPdfRequest req,
  _LedgerPdfStyles styles,
  pw.TextDirection textDirection,
) {
  final hasMerchantBranding = req.merchantStoreName != null &&
      req.merchantStoreName!.trim().isNotEmpty;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: <pw.Widget>[
      pw.Container(
        height: 5,
        decoration: PdfPremiumLayout.accentStripDecoration(),
      ),
      pw.SizedBox(height: 14),
      if (hasMerchantBranding)
        _buildLedgerBrandedHeaderRow(req, styles, textDirection)
      else
        _buildLedgerDefaultHeaderRow(req, styles),
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: PdfPremiumLayout.titleCardDecoration(),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              req.titleSummary,
              style: styles.text(size: 18, emphasize: true),
            ),
            pw.SizedBox(height: 6),
            _ledgerLabelValueRow(
              styles: styles,
              label: req.labelLedgerName,
              value: req.ledgerName,
              labelSize: 12,
              valueSize: 12,
              color: PdfBrandColors.inkSecondary,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
    ],
  );
}

pw.Widget _buildLedgerDefaultHeaderRow(
  _LedgerSummaryPdfRequest req,
  _LedgerPdfStyles styles,
) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: <pw.Widget>[
      pw.Text(
        req.applicationName,
        style: styles.text(
          size: 16,
          emphasize: true,
        ),
      ),
      _ledgerLabelValueRow(
        styles: styles,
        label: req.labelGeneratedOn,
        value: req.generatedOnValue,
        labelSize: 9,
        valueSize: 9,
        color: PdfBrandColors.inkSecondary,
      ),
    ],
  );
}

pw.Widget _buildLedgerBrandedHeaderRow(
  _LedgerSummaryPdfRequest req,
  _LedgerPdfStyles styles,
  pw.TextDirection textDirection,
) {
  final merchantInfoChildren = <pw.Widget>[
    _ledgerScriptAwareText(
      req.merchantStoreName!,
      styles.text(size: 16, emphasize: true),
      pageDirection: textDirection,
    ),
  ];
  if (req.merchantStorePhone != null &&
      req.merchantStorePhone!.trim().isNotEmpty) {
    merchantInfoChildren
      ..add(pw.SizedBox(height: 2))
      ..add(
        _ledgerScriptAwareText(
          req.merchantStorePhone!,
          styles.text(size: 9, color: PdfBrandColors.inkSecondary),
          pageDirection: textDirection,
        ),
      );
  }

  pw.Widget? logoWidget;
  if (req.merchantLogoBytes != null && req.merchantLogoBytes!.isNotEmpty) {
    try {
      final image = pw.MemoryImage(req.merchantLogoBytes!);
      logoWidget = pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Image(
          image,
          width: 48,
          height: 48,
          fit: pw.BoxFit.cover,
        ),
      );
    } on Object {
      logoWidget = null;
    }
  }

  final leadingChildren = <pw.Widget>[
    if (logoWidget != null) ...[
      logoWidget,
      pw.SizedBox(width: 12),
    ],
    pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: merchantInfoChildren,
      ),
    ),
  ];

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: <pw.Widget>[
      pw.Row(
        children: <pw.Widget>[
          ...leadingChildren,
          _ledgerLabelValueRow(
            styles: styles,
            label: req.labelGeneratedOn,
            value: req.generatedOnValue,
            labelSize: 9,
            valueSize: 9,
            color: PdfBrandColors.inkSecondary,
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      PdfPremiumLayout.hairlineDivider(color: PdfBrandColors.lapisBorderSoft),
    ],
  );
}

List<pw.Widget> _buildLedgerBody(
  _LedgerSummaryPdfRequest req,
  _LedgerPdfStyles styles,
  List<_LedgerCurrencySection> sections,
  pw.TextDirection textDirection,
) {
  return sections
      .asMap()
      .entries
      .expand((entry) {
        final section = entry.value;
        return <pw.Widget>[
          if (entry.key > 0) pw.SizedBox(height: PdfPremiumLayout.sectionGap),
          pw.Directionality(
            textDirection: textDirection,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: PdfPremiumLayout.currencyBadgeDecoration(),
              child: _ledgerLabelValueRow(
                styles: styles,
                label: req.labelCurrency,
                value: section.currencyCode,
                labelSize: 11,
                valueSize: 11,
                color: PdfBrandColors.inkOnLapis,
                emphasize: true,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Directionality(
            textDirection: textDirection,
            child: _buildLedgerContactsTable(
              req,
              styles,
              section.tableRows,
              textDirection,
            ),
          ),
          pw.SizedBox(height: PdfPremiumLayout.summaryTopBreathing),
          pw.Directionality(
            textDirection: textDirection,
            child: _buildLedgerSectionSummaryCard(req, styles, section),
          ),
          pw.SizedBox(height: PdfPremiumLayout.summaryBottomBreathing),
        ];
      })
      .toList(growable: false);
}

pw.Widget _buildLedgerSectionSummaryCard(
  _LedgerSummaryPdfRequest req,
  _LedgerPdfStyles styles,
  _LedgerCurrencySection section,
) {
  final balanceColor = section.rawNetBalance == 0
      ? PdfBrandColors.inkPrimary
      : (section.rawNetBalance < 0 ? PdfBrandColors.debt : PdfBrandColors.payment);

  return pw.Container(
    padding: PdfPremiumLayout.summaryCardPadding,
    decoration: PdfPremiumLayout.summaryCardDecoration(),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        pw.Text(
          req.labelTotalLedgerBalance,
          style: styles.text(size: 11, color: PdfBrandColors.inkSecondary, emphasize: true),
        ),
        pw.SizedBox(height: 10),
        _ledgerSummaryRow(
          styles,
          req.labelTotalDebt,
          section.totalDebtValue,
          PdfBrandColors.debt,
        ),
        pw.SizedBox(height: 8),
        _ledgerSummaryRow(
          styles,
          req.labelTotalPayment,
          section.totalPaymentValue,
          PdfBrandColors.payment,
        ),
        pw.SizedBox(height: 10),
        PdfPremiumLayout.hairlineDivider(color: PdfBrandColors.lapisBorderSoft),
        pw.SizedBox(height: 10),
        _ledgerSummaryRow(
          styles,
          req.labelNetBalance,
          section.netBalanceValue,
          balanceColor,
          emphasize: true,
        ),
      ],
    ),
  );
}

pw.Widget _ledgerSummaryRow(
  _LedgerPdfStyles styles,
  String label,
  String value,
  PdfColor valueColor, {
  bool emphasize = false,
}) {
  final labelStyle = emphasize
      ? styles.text(size: 12, emphasize: true)
      : styles.text(size: 11, color: PdfBrandColors.inkSecondary);
  final valueStyle = styles.text(
    size: emphasize ? 14 : 11,
    color: valueColor,
    emphasize: true,
  );

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: <pw.Widget>[
      pw.Expanded(
        child: pw.Text(label, style: labelStyle, textAlign: pw.TextAlign.start),
      ),
      pw.SizedBox(width: 12),
      pw.Text(value, style: valueStyle, textAlign: pw.TextAlign.end),
    ],
  );
}

List<_LedgerCurrencySection> _buildLedgerCurrencySections(
  _LedgerSummaryPdfRequest req,
  NumberFormat amountFmt,
) {
  final totalsByCurrency = <String, _LedgerTotalInput>{
    for (final total in req.ledgerTotals)
      total.currencyCode.trim().toUpperCase(): total,
  };

  final grouped = <String, List<_LedgerContactInput>>{};
  for (final contact in req.contacts) {
    final raw = contact.currencyCode.trim();
    final code = raw.isEmpty ? '' : raw.toUpperCase();
    grouped.putIfAbsent(code, () => <_LedgerContactInput>[]).add(contact);
  }

  for (final code in totalsByCurrency.keys) {
    grouped.putIfAbsent(code, () => <_LedgerContactInput>[]);
  }

  if (grouped.isEmpty) {
    grouped[''] = <_LedgerContactInput>[];
  }

  final sortedCodes = grouped.keys.toList()
    ..sort((left, right) {
      if (left.isEmpty && right.isNotEmpty) {
        return 1;
      }
      if (right.isEmpty && left.isNotEmpty) {
        return -1;
      }
      return left.compareTo(right);
    });

  return sortedCodes
      .map((code) {
        final contacts = List<_LedgerContactInput>.from(grouped[code]!)
          ..sort((left, right) => left.name.compareTo(right.name));

        final displayCode = code.isEmpty ? '—' : code;
        final totalRow = totalsByCurrency[code];

        var totalDebt = 0;
        var totalPayment = 0;
        var netBalance = 0;

        if (totalRow != null) {
          totalDebt = totalRow.totalDebt;
          totalPayment = totalRow.totalPayment;
          netBalance = totalRow.netBalance;
        } else {
          for (final contact in contacts) {
            netBalance += contact.netBalance;
          }
        }

        return _LedgerCurrencySection(
          currencyCode: displayCode,
          tableRows: _buildLedgerContactTableRows(contacts, amountFmt),
          totalDebtValue: _ledgerFmtAmount(amountFmt, totalDebt, displayCode),
          totalPaymentValue: _ledgerFmtAmount(
            amountFmt,
            totalPayment,
            displayCode,
          ),
          netBalanceValue: _ledgerFmtAmount(
            amountFmt,
            netBalance,
            displayCode,
          ),
          rawNetBalance: netBalance,
        );
      })
      .toList(growable: false);
}

pw.Widget _buildLedgerContactsTable(
  _LedgerSummaryPdfRequest req,
  _LedgerPdfStyles styles,
  List<_LedgerContactTableRow> rows,
  pw.TextDirection textDirection,
) {
  final headerStyle = styles.text(
    color: PdfBrandColors.inkOnLapis,
    emphasize: true,
  );

  final headerCells = <pw.Widget>[
    _ledgerCell(req.labelRowNumber, headerStyle, alignment: _LedgerCellAlign.center),
    _ledgerCell(req.labelName, headerStyle, alignment: _LedgerCellAlign.start),
    _ledgerCell(req.labelPhone, headerStyle, alignment: _LedgerCellAlign.start),
    _ledgerCell(req.labelNetBalance, headerStyle, alignment: _LedgerCellAlign.end),
  ];

  final tableRows = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: PdfPremiumLayout.headerRowDecoration(),
      children: req.isRtl
          ? headerCells.reversed.toList(growable: false)
          : headerCells,
    ),
    ...rows.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;
      final stripeColor = index.isEven ? PdfBrandColors.pearlStripe : PdfColors.white;
      final balanceColor = row.rawNetBalance == 0
          ? PdfBrandColors.inkPrimary
          : (row.rawNetBalance < 0 ? PdfBrandColors.debt : PdfBrandColors.payment);

      final cells = <pw.Widget>[
        _ledgerCell(
          row.indexLabel,
          styles.text(size: 9),
          alignment: _LedgerCellAlign.center,
        ),
        _ledgerScriptAwareCell(
          row.name,
          styles.text(size: 9, emphasize: true),
          textDirection,
        ),
        _ledgerScriptAwareCell(
          row.phone,
          styles.text(size: 9, color: PdfBrandColors.inkSecondary),
          textDirection,
        ),
        _ledgerCell(
          row.balance,
          styles.text(size: 9, color: balanceColor, emphasize: true),
          alignment: _LedgerCellAlign.end,
        ),
      ];

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: stripeColor),
        children: req.isRtl
            ? cells.reversed.toList(growable: false)
            : cells,
      );
    }),
  ];

  final columnWidths = req.isRtl
      ? const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(2.5),
          2: pw.FlexColumnWidth(2.5),
          3: pw.FlexColumnWidth(1.2),
        }
      : const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(1.2),
          1: pw.FlexColumnWidth(2.5),
          2: pw.FlexColumnWidth(2.5),
          3: pw.FlexColumnWidth(2.2),
        };

  return pw.Table(
    border: PdfPremiumLayout.dataTableBorder,
    columnWidths: columnWidths,
    children: tableRows,
  );
}

enum _LedgerCellAlign { start, end, center }

pw.Widget _ledgerCell(
  String text,
  pw.TextStyle style, {
  required _LedgerCellAlign alignment,
}) {
  final align = switch (alignment) {
    _LedgerCellAlign.end => pw.TextAlign.end,
    _LedgerCellAlign.center => pw.TextAlign.center,
    _ => pw.TextAlign.start,
  };
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(
      text,
      style: style,
      textAlign: align,
      maxLines: 2,
    ),
  );
}

pw.Widget _ledgerScriptAwareCell(
  String text,
  pw.TextStyle style,
  pw.TextDirection pageDirection,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: _ledgerScriptAwareText(
      text,
      style,
      pageDirection: pageDirection,
      maxLines: 2,
    ),
  );
}

pw.Widget _buildLedgerFooter(
  _LedgerSummaryPdfRequest req,
  _LedgerPdfStyles styles,
  pw.Context context,
) {
  return pw.Column(
    children: <pw.Widget>[
      PdfPremiumLayout.hairlineDivider(),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            req.applicationName,
            style: styles.text(size: 8, color: PdfBrandColors.inkSecondary),
          ),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              pw.Text(
                req.labelPage,
                style: styles.text(size: 9, color: PdfBrandColors.inkSecondary),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: styles.text(size: 9, color: PdfBrandColors.inkSecondary),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

List<_LedgerContactTableRow> _buildLedgerContactTableRows(
  List<_LedgerContactInput> contacts,
  NumberFormat amountFmt,
) {
  return contacts
      .asMap()
      .entries
      .map((entry) {
        final index = entry.key + 1;
        final contact = entry.value;
        final phone = contact.phone == null || contact.phone!.trim().isEmpty
            ? '-'
            : contact.phone!.trim();
        final currency = contact.currencyCode.trim();
        return _LedgerContactTableRow(
          indexLabel: '$index',
          name: contact.name,
          phone: phone,
          balance: _ledgerFmtAmount(
            amountFmt,
            contact.netBalance,
            currency,
          ),
          rawNetBalance: contact.netBalance,
        );
      })
      .toList(growable: false);
}

String _ledgerFmtAmount(NumberFormat fmt, int amount, String currency) {
  final sanitizedCurrency = _ledgerSanitizePdfText(currency).trim();
  final formattedAmount = MoneyUtil.formatMinorUnitsForCode(
    amount,
    sanitizedCurrency.isEmpty ? currency : sanitizedCurrency,
  );
  final formatted = sanitizedCurrency.isEmpty
      ? formattedAmount
      : '$formattedAmount $sanitizedCurrency';
  return _ledgerSanitizePdfText(formatted);
}

String _ledgerSanitizePdfText(String input) {
  if (input.isEmpty) {
    return input;
  }

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    switch (rune) {
      case 0x00A0:
      case 0x1680:
      case 0x2000:
      case 0x2001:
      case 0x2002:
      case 0x2003:
      case 0x2004:
      case 0x2005:
      case 0x2006:
      case 0x2007:
      case 0x2008:
      case 0x2009:
      case 0x200A:
      case 0x202F:
      case 0x205F:
      case 0x3000:
        buffer.write(' ');
      case 0x00AD:
      case 0x061C:
      case 0x200B:
      case 0x200C:
      case 0x200D:
      case 0x200E:
      case 0x200F:
      case 0x202A:
      case 0x202B:
      case 0x202C:
      case 0x202D:
      case 0x202E:
      case 0x2060:
      case 0x2066:
      case 0x2067:
      case 0x2068:
      case 0x2069:
      case 0xFEFF:
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }

  return buffer.toString();
}

pw.Widget _ledgerLabelValueRow({
  required _LedgerPdfStyles styles,
  required String label,
  required String value,
  required double labelSize,
  required double valueSize,
  PdfColor color = PdfBrandColors.inkPrimary,
  bool emphasize = false,
}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: <pw.Widget>[
      pw.Text(
        label,
        style: styles.text(size: labelSize, color: color, emphasize: emphasize),
      ),
      pw.Text(
        ': ',
        style: styles.text(size: labelSize, color: color, emphasize: emphasize),
      ),
      pw.Flexible(
        child: pw.Text(
          value,
          style: styles.text(
            size: valueSize,
            color: color,
            emphasize: emphasize,
          ),
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
        ),
      ),
    ],
  );
}

bool _ledgerContainsArabicScript(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}

pw.TextDirection _ledgerRunTextDirection(
  String text, {
  required pw.TextDirection pageDirection,
}) {
  if (_ledgerContainsArabicScript(text)) {
    return pw.TextDirection.rtl;
  }
  return pageDirection;
}

pw.Widget _ledgerScriptAwareText(
  String raw,
  pw.TextStyle style, {
  required pw.TextDirection pageDirection,
  int? maxLines,
}) {
  final text = _ledgerSanitizePdfText(raw);
  final runDirection = _ledgerRunTextDirection(
    text,
    pageDirection: pageDirection,
  );
  final child = pw.Text(
    text,
    style: style,
    textDirection: runDirection,
    maxLines: maxLines,
  );
  if (runDirection != pageDirection) {
    return pw.Directionality(
      textDirection: runDirection,
      child: child,
    );
  }
  return child;
}

final class _LedgerContactTableRow {
  const _LedgerContactTableRow({
    required this.indexLabel,
    required this.name,
    required this.phone,
    required this.balance,
    required this.rawNetBalance,
  });

  final String indexLabel;
  final String name;
  final String phone;
  final String balance;
  final int rawNetBalance;
}

final class _LedgerCurrencySection {
  const _LedgerCurrencySection({
    required this.currencyCode,
    required this.tableRows,
    required this.totalDebtValue,
    required this.totalPaymentValue,
    required this.netBalanceValue,
    required this.rawNetBalance,
  });

  final String currencyCode;
  final List<_LedgerContactTableRow> tableRows;
  final String totalDebtValue;
  final String totalPaymentValue;
  final String netBalanceValue;
  final int rawNetBalance;
}

final class _LedgerSummaryPdfRequest {
  const _LedgerSummaryPdfRequest({
    required this.applicationName,
    required this.localeTag,
    required this.isRtl,
    required this.regularFontBytes,
    required this.boldFontBytes,
    required this.fallbackRegularFontBytes,
    required this.fallbackBoldFontBytes,
    required this.titleSummary,
    required this.labelLedgerName,
    required this.labelGeneratedOn,
    required this.labelTotalLedgerBalance,
    required this.labelTotalDebt,
    required this.labelTotalPayment,
    required this.labelNetBalance,
    required this.labelRowNumber,
    required this.labelName,
    required this.labelPhone,
    required this.labelCurrency,
    required this.labelPage,
    required this.ledgerName,
    required this.generatedOnValue,
    required this.contacts,
    required this.ledgerTotals,
    required this.msgPreparing,
    required this.msgGrouping,
    required this.msgBuilding,
    required this.msgRendering,
    this.merchantStoreName,
    this.merchantStorePhone,
    this.merchantLogoBytes,
  });

  factory _LedgerSummaryPdfRequest.fromMap(Map<String, Object?> map) {
    final rawContacts = _ledgerRequiredValue<List<Map<String, Object?>>>(
      map,
      'contacts',
    );
    final rawTotals = _ledgerRequiredValue<List<Map<String, Object?>>>(
      map,
      'ledgerTotals',
    );

    return _LedgerSummaryPdfRequest(
      applicationName: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'applicationName'),
      ),
      localeTag: _ledgerRequiredValue<String>(map, 'localeTag'),
      isRtl: _ledgerRequiredValue<bool>(map, 'isRtl'),
      regularFontBytes: _ledgerRequiredValue<Uint8List>(map, 'regularFontBytes'),
      boldFontBytes: _ledgerRequiredValue<Uint8List>(map, 'boldFontBytes'),
      fallbackRegularFontBytes: _ledgerRequiredValue<Uint8List>(
        map,
        'fallbackRegularFontBytes',
      ),
      fallbackBoldFontBytes: _ledgerRequiredValue<Uint8List>(
        map,
        'fallbackBoldFontBytes',
      ),
      titleSummary: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'titleSummary'),
      ),
      labelLedgerName: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelLedgerName'),
      ),
      labelGeneratedOn: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelGeneratedOn'),
      ),
      labelTotalLedgerBalance: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelTotalLedgerBalance'),
      ),
      labelTotalDebt: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelTotalDebt'),
      ),
      labelTotalPayment: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelTotalPayment'),
      ),
      labelNetBalance: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelNetBalance'),
      ),
      labelRowNumber: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelRowNumber'),
      ),
      labelName: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelName'),
      ),
      labelPhone: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelPhone'),
      ),
      labelCurrency: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelCurrency'),
      ),
      labelPage: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'labelPage'),
      ),
      ledgerName: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'ledgerName'),
      ),
      generatedOnValue: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'generatedOnValue'),
      ),
      contacts: rawContacts
          .map(_LedgerContactInput.fromMap)
          .toList(growable: false),
      ledgerTotals: rawTotals
          .map(_LedgerTotalInput.fromMap)
          .toList(growable: false),
      msgPreparing: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'msgPreparing'),
      ),
      msgGrouping: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'msgGrouping'),
      ),
      msgBuilding: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'msgBuilding'),
      ),
      msgRendering: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'msgRendering'),
      ),
      merchantStoreName: map['merchantStoreName'] as String?,
      merchantStorePhone: map['merchantStorePhone'] as String?,
      merchantLogoBytes: map['merchantLogoBytes'] as Uint8List?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'applicationName': _ledgerSanitizePdfText(applicationName),
      'localeTag': localeTag,
      'isRtl': isRtl,
      'regularFontBytes': regularFontBytes,
      'boldFontBytes': boldFontBytes,
      'fallbackRegularFontBytes': fallbackRegularFontBytes,
      'fallbackBoldFontBytes': fallbackBoldFontBytes,
      'titleSummary': _ledgerSanitizePdfText(titleSummary),
      'labelLedgerName': _ledgerSanitizePdfText(labelLedgerName),
      'labelGeneratedOn': _ledgerSanitizePdfText(labelGeneratedOn),
      'labelTotalLedgerBalance': _ledgerSanitizePdfText(
        labelTotalLedgerBalance,
      ),
      'labelTotalDebt': _ledgerSanitizePdfText(labelTotalDebt),
      'labelTotalPayment': _ledgerSanitizePdfText(labelTotalPayment),
      'labelNetBalance': _ledgerSanitizePdfText(labelNetBalance),
      'labelRowNumber': _ledgerSanitizePdfText(labelRowNumber),
      'labelName': _ledgerSanitizePdfText(labelName),
      'labelPhone': _ledgerSanitizePdfText(labelPhone),
      'labelCurrency': _ledgerSanitizePdfText(labelCurrency),
      'labelPage': _ledgerSanitizePdfText(labelPage),
      'ledgerName': _ledgerSanitizePdfText(ledgerName),
      'generatedOnValue': _ledgerSanitizePdfText(generatedOnValue),
      'contacts': contacts.map((c) => c.toMap()).toList(growable: false),
      'ledgerTotals': ledgerTotals.map((t) => t.toMap()).toList(growable: false),
      'msgPreparing': _ledgerSanitizePdfText(msgPreparing),
      'msgGrouping': _ledgerSanitizePdfText(msgGrouping),
      'msgBuilding': _ledgerSanitizePdfText(msgBuilding),
      'msgRendering': _ledgerSanitizePdfText(msgRendering),
      'merchantStoreName': merchantStoreName,
      'merchantStorePhone': merchantStorePhone,
      'merchantLogoBytes': merchantLogoBytes,
    };
  }

  final String applicationName;
  final String localeTag;
  final bool isRtl;
  final Uint8List regularFontBytes;
  final Uint8List boldFontBytes;
  final Uint8List fallbackRegularFontBytes;
  final Uint8List fallbackBoldFontBytes;
  final String titleSummary;
  final String labelLedgerName;
  final String labelGeneratedOn;
  final String labelTotalLedgerBalance;
  final String labelTotalDebt;
  final String labelTotalPayment;
  final String labelNetBalance;
  final String labelRowNumber;
  final String labelName;
  final String labelPhone;
  final String labelCurrency;
  final String labelPage;
  final String ledgerName;
  final String generatedOnValue;
  final List<_LedgerContactInput> contacts;
  final List<_LedgerTotalInput> ledgerTotals;
  final String msgPreparing;
  final String msgGrouping;
  final String msgBuilding;
  final String msgRendering;
  final String? merchantStoreName;
  final String? merchantStorePhone;
  final Uint8List? merchantLogoBytes;
}

final class _LedgerContactInput {
  const _LedgerContactInput({
    required this.name,
    required this.netBalance,
    required this.currencyCode,
    this.phone,
  });

  factory _LedgerContactInput.fromMap(Map<String, Object?> map) {
    final phoneValue = map['phone'];
    final String? phone;
    if (phoneValue == null) {
      phone = null;
    } else if (phoneValue is String) {
      phone = _ledgerSanitizePdfText(phoneValue);
    } else {
      throw const FormatException('Expected "phone" to be a String or null');
    }

    return _LedgerContactInput(
      name: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'name'),
      ),
      phone: phone,
      netBalance: _ledgerRequiredValue<int>(map, 'netBalance'),
      currencyCode: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'currencyCode'),
      ).trim(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': _ledgerSanitizePdfText(name),
      'phone': phone == null ? null : _ledgerSanitizePdfText(phone!),
      'netBalance': netBalance,
      'currencyCode': _ledgerSanitizePdfText(currencyCode).trim(),
    };
  }

  final String name;
  final String? phone;
  final int netBalance;
  final String currencyCode;
}

final class _LedgerTotalInput {
  const _LedgerTotalInput({
    required this.currencyCode,
    required this.totalDebt,
    required this.totalPayment,
    required this.netBalance,
  });

  factory _LedgerTotalInput.fromMap(Map<String, Object?> map) {
    return _LedgerTotalInput(
      currencyCode: _ledgerSanitizePdfText(
        _ledgerRequiredValue<String>(map, 'currencyCode'),
      ).trim(),
      totalDebt: _ledgerRequiredValue<int>(map, 'totalDebt'),
      totalPayment: _ledgerRequiredValue<int>(map, 'totalPayment'),
      netBalance: _ledgerRequiredValue<int>(map, 'netBalance'),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'currencyCode': _ledgerSanitizePdfText(currencyCode).trim(),
      'totalDebt': totalDebt,
      'totalPayment': totalPayment,
      'netBalance': netBalance,
    };
  }

  final String currencyCode;
  final int totalDebt;
  final int totalPayment;
  final int netBalance;
}

T _ledgerRequiredValue<T>(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is T) {
    return value;
  }
  throw FormatException('Expected "$key" to be $T');
}

final class _LedgerProgressMsg {
  const _LedgerProgressMsg(this.progress, this.message);

  final double progress;
  final String message;
}

final class _LedgerErrorMsg {
  const _LedgerErrorMsg(this.error, this.stackTrace);

  final String error;
  final String stackTrace;
}
