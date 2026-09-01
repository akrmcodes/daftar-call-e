import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/pdf_colors.dart';
import 'package:daftar/core/utils/pdf_premium_layout.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ============================================================================
// Font asset paths — Cairo is the dual-script PDF face (Arabic + Latin in a
// single TTF, eliminating the dart_pdf 3.12 fontFallback span-split bug).
// Inter is wired as a defensive fallback for any exotic codepoint Cairo might
// not cover (e.g. ®, ©, currency-specific glyphs).
// ============================================================================
const _fontCairoRegular = 'assets/fonts/Cairo-Regular.ttf';
const _fontCairoBold = 'assets/fonts/Cairo-Bold.ttf';
const _fontInterRegular = 'assets/fonts/Inter-Regular.ttf';
const _fontInterBold = 'assets/fonts/Inter-Bold.ttf';

/// Hard ceiling for the entire PDF generation pipeline (isolate spawn + build
/// + save). Beyond this, we kill the isolate and surface a TimeoutException
/// to the caller so the UI never silently hangs.
const Duration _generationTimeout = Duration(seconds: 30);

/// Generates premium, localized contact statement PDFs.
///
/// All heavy work runs in a spawned isolate. Fonts are loaded ONCE per app
/// session via [_FontCache] and shipped across the isolate boundary as
/// [TransferableTypedData] (zero-copy). The isolate is hardened with explicit
/// `onError` + `onExit` ports and a wall-clock timeout, so the future returned
/// here is guaranteed to complete in bounded time.
abstract final class PdfGenerator {
  static Future<void> preWarmFonts() async {
    await _FontCache.instance.load();
  }

  /// Builds and returns a localized contact statement PDF document.
  static Future<Uint8List> generateContactStatement({
    required Contact contact,
    required ContactBalance contactBalance,
    required List<Transaction> transactions,
    required bool isRtl,
    required String applicationName,
    required String labelStatement,
    required String labelContactName,
    required String labelGeneratedOn,
    required String labelTotalDebt,
    required String labelTotalPayment,
    required String labelNetBalance,
    required String labelDate,
    required String labelDetails,
    required String labelDebt,
    required String labelPayment,
    required String labelRunningBalance,
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
    String? statementPeriodText,
    MerchantProfile? merchantProfile,
  }) async {
    // ── Step 2: Spawn the build isolate with full lifecycle ports ─
    // The spawn message must stay sendable. Flatten the request to plain
    // maps/lists so the isolate boundary never receives custom DTO objects.
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
      if (message is _ProgressMsg) {
        onProgress?.call(message.progress, message.message);
        return;
      }
      if (message is Uint8List) {
        if (!completer.isCompleted) completer.complete(message);
        cleanup();
        return;
      }
      if (message is _ErrorMsg) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(message.error),
            StackTrace.fromString(message.stackTrace),
          );
        }
        cleanup();
      }
    });

    // Uncaught throws inside the isolate land here as [error, stackTrace] lists.
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

    // Premature isolate death (e.g. OOM) without a payload reply.
    exitSub = exitPort.listen((_) {
      if (completer.isCompleted) return;
      completer.completeError(
        Exception('PDF isolate exited unexpectedly'),
      );
      cleanup();
    });

    final payload = await buildIsolatePayload(
      sendPort: receivePort.sendPort,
      contact: contact,
      contactBalance: contactBalance,
      transactions: transactions,
      isRtl: isRtl,
      applicationName: applicationName,
      labelStatement: labelStatement,
      labelContactName: labelContactName,
      labelGeneratedOn: labelGeneratedOn,
      labelTotalDebt: labelTotalDebt,
      labelTotalPayment: labelTotalPayment,
      labelNetBalance: labelNetBalance,
      labelDate: labelDate,
      labelDetails: labelDetails,
      labelDebt: labelDebt,
      labelPayment: labelPayment,
      labelRunningBalance: labelRunningBalance,
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
      statementPeriodText: statementPeriodText,
      merchantProfile: merchantProfile,
    );

    try {
      isolate = await Isolate.spawn<Map<String, Object?>>(
        _buildPdfIsolate,
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
        'PDF generation exceeded ${_generationTimeout.inSeconds}s',
        _generationTimeout,
      );
    }
  }

  /// Builds the exact flattened payload sent to the worker isolate.
  ///
  /// Exposed for tests so they can validate the sendable structure without
  /// mocking `Isolate.spawn`.
  static Future<Map<String, Object?>> buildIsolatePayload({
    required SendPort sendPort,
    required Contact contact,
    required ContactBalance contactBalance,
    required List<Transaction> transactions,
    required bool isRtl,
    required String applicationName,
    required String labelStatement,
    required String labelContactName,
    required String labelGeneratedOn,
    required String labelTotalDebt,
    required String labelTotalPayment,
    required String labelNetBalance,
    required String labelDate,
    required String labelDetails,
    required String labelDebt,
    required String labelPayment,
    required String labelRunningBalance,
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
    String? statementPeriodText,
    MerchantProfile? merchantProfile,
  }) async {
    final localeTag = isRtl ? 'ar' : 'en';

    final hasFontOverrides =
        cairoRegularFontBytes != null &&
        cairoBoldFontBytes != null &&
        interRegularFontBytes != null &&
        interBoldFontBytes != null;

    final fonts = hasFontOverrides
        ? _FontBundle(
            cairoRegular: cairoRegularFontBytes,
            cairoBold: cairoBoldFontBytes,
            interRegular: interRegularFontBytes,
            interBold: interBoldFontBytes,
          )
        : await _FontCache.instance.load();

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
      'titleStatement': labelStatement,
      'labelContactName': labelContactName,
      'labelGeneratedOn': labelGeneratedOn,
      'labelTotalDebt': labelTotalDebt,
      'labelTotalPayment': labelTotalPayment,
      'labelNetBalance': labelNetBalance,
      'labelDate': labelDate,
      'labelDetails': labelDetails,
      'labelDebt': labelDebt,
      'labelPayment': labelPayment,
      'labelRunningBalance': labelRunningBalance,
      'labelCurrency': labelCurrency,
      'labelPage': labelPage,
      'contactName': contact.name,
      'deferGeneratedOn': generatedOnValue == null,
      'generatedOnValue': generatedOnValue ?? '',
      'statementPeriodText': statementPeriodText ?? '',
      'fallbackCurrencyCode': contactBalance.currencyCode.trim(),
      'fallbackTotalDebt': contactBalance.totalDebt,
      'fallbackTotalPayment': contactBalance.totalPayment,
      'fallbackNetBalance': contactBalance.netBalance,
      'transactions': transactions
          .map(
            (t) => <String, Object?>{
              'currency': t.currency,
              'amount': t.amount,
              'itemName': t.itemName,
              'description': t.description,
              'transactionDate': t.transactionDate.toIso8601String(),
              'createdAt': t.createdAt.toIso8601String(),
              'type': t.type.name,
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

// ============================================================================
// Font cache — loads Cairo + Inter ONCE per app session.
// ============================================================================

/// In-memory cache for the four PDF font payloads. Loading happens on the
/// first export (on the main isolate via [rootBundle]); subsequent exports
/// reuse the cached [Uint8List]s without round-tripping the asset bundle.
final class _FontCache {
  _FontCache._();

  static final _FontCache instance = _FontCache._();

  Future<_FontBundle>? _loading;

  Future<_FontBundle> load() {
    return _loading ??= _loadOnce();
  }

  Future<_FontBundle> _loadOnce() async {
    final results = await Future.wait<ByteData>(<Future<ByteData>>[
      rootBundle.load(_fontCairoRegular),
      rootBundle.load(_fontCairoBold),
      rootBundle.load(_fontInterRegular),
      rootBundle.load(_fontInterBold),
    ]);

    Uint8List slice(ByteData data) =>
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    return _FontBundle(
      cairoRegular: slice(results[0]),
      cairoBold: slice(results[1]),
      interRegular: slice(results[2]),
      interBold: slice(results[3]),
    );
  }
}

final class _FontBundle {
  const _FontBundle({
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

// ============================================================================
// Isolate entry point
// ============================================================================

Future<void> _buildPdfIsolate(Map<String, Object?> payload) async {
  final sendPort = _requiredValue<SendPort>(payload, 'sendPort');
  final localeTag = _requiredValue<String>(payload, 'localeTag');

  await initializeDateFormatting(localeTag);

  try {
    final requestMap = Map<String, Object?>.from(
      _requiredValue<Map<String, Object?>>(payload, 'request'),
    );
    requestMap['regularFontBytes'] = _materializeFontBytes(
      payload['regularFontTransferable'],
    );
    requestMap['boldFontBytes'] = _materializeFontBytes(
      payload['boldFontTransferable'],
    );
    requestMap['fallbackRegularFontBytes'] = _materializeFontBytes(
      payload['fallbackRegularFontTransferable'],
    );
    requestMap['fallbackBoldFontBytes'] = _materializeFontBytes(
      payload['fallbackBoldFontTransferable'],
    );
    if (requestMap['deferGeneratedOn'] == true) {
      requestMap['generatedOnValue'] = _sanitizePdfText(
        DateFormat.yMMMd(AppConstants.numeralLocale).format(DateTime.now()),
      );
    }
    requestMap.remove('deferGeneratedOn');

    final request = _PdfRequest.fromMap(requestMap);
    final bytes = await _buildPdfBytes(request, sendPort);
    sendPort.send(bytes);
  } on Object catch (error, stackTrace) {
    sendPort.send(
      _ErrorMsg(error.toString(), stackTrace.toString()),
    );
  }
}

Uint8List _materializeFontBytes(Object? value) {
  if (value is TransferableTypedData) {
    return value.materialize().asUint8List();
  }
  if (value is Uint8List) {
    return value;
  }
  throw const FormatException('Expected TransferableTypedData or Uint8List font');
}

// ============================================================================
// PDF document builder — runs entirely inside the isolate
// ============================================================================

Future<Uint8List> _buildPdfBytes(
  _PdfRequest req,
  SendPort sendPort,
) async {
  // Phase 1: Prepare fonts (constructed ONLY here, inside the isolate).
  sendPort.send(_ProgressMsg(0.10, req.msgPreparing));

  ByteData asByteData(Uint8List bytes) =>
      ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

  final cairoRegular = pw.Font.ttf(asByteData(req.regularFontBytes));
  final cairoBold = pw.Font.ttf(asByteData(req.boldFontBytes));
  final interRegular = pw.Font.ttf(asByteData(req.fallbackRegularFontBytes));
  final interBold = pw.Font.ttf(asByteData(req.fallbackBoldFontBytes));

  final styles = _PdfStyles(
    base: cairoRegular,
    bold: cairoBold,
    fallback: <pw.Font>[interRegular, interBold],
  );

  final textDirection = req.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  // Phase 2: Group and sort transactions by currency
  sendPort.send(_ProgressMsg(0.30, req.msgGrouping));
  final sections = _buildCurrencySections(req);

  // Phase 3: Build layout
  sendPort.send(_ProgressMsg(0.60, req.msgBuilding));

  final document = pw.Document()
    ..addPage(
      pw.MultiPage(
        maxPages: 1000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: textDirection,
          // Theme is set defensively, but EVERY pw.Text in this document
          // receives an explicit pw.TextStyle from `styles` — we never rely
          // on theme cascading (which is where dart_pdf 3.12 inheritance
          // bugs live).
          theme: pw.ThemeData.withFont(
            base: cairoRegular,
            bold: cairoBold,
            fontFallback: <pw.Font>[interRegular, interBold],
          ),
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        ),
        footer: (context) => pw.Directionality(
          textDirection: textDirection,
          child: _buildFooter(req, styles, context),
        ),
        build: (context) {
          return <pw.Widget>[
            pw.Directionality(
              textDirection: textDirection,
              child: _buildHeader(req, styles, textDirection),
            ),
            ..._buildBody(req, styles, sections, textDirection),
          ];
        },
      ),
    );

  // Phase 4: Render
  sendPort.send(_ProgressMsg(0.90, req.msgRendering));
  return document.save();
}

// ============================================================================
// Style helper — every pw.Text in the document goes through this.
// ============================================================================

final class _PdfStyles {
  _PdfStyles({
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

// ============================================================================
// Premium header — branded accent bar + app name + contact info
// ============================================================================

pw.Widget _buildHeader(
  _PdfRequest req,
  _PdfStyles styles,
  pw.TextDirection textDirection,
) {
  final hasMerchantBranding = req.merchantStoreName != null &&
      req.merchantStoreName!.trim().isNotEmpty;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: <pw.Widget>[
      // Lapis gradient accent strip
      pw.Container(
        height: 5,
        decoration: PdfPremiumLayout.accentStripDecoration(),
      ),
      pw.SizedBox(height: 14),
      // ── Branded header (when MerchantProfile is present) ──
      if (hasMerchantBranding)
        _buildBrandedHeaderRow(req, styles, textDirection)
      else
        // ── Default header (app-name only) ──
        _buildDefaultHeaderRow(req, styles),
      pw.SizedBox(height: 16),
      // Statement title + contact-name card
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: PdfPremiumLayout.titleCardDecoration(),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              req.titleStatement,
              style: styles.text(size: 18, emphasize: true),
            ),
            pw.SizedBox(height: 4),
            _labelValueRow(
              styles: styles,
              label: req.labelContactName,
              value: req.contactName,
              labelSize: 12,
              valueSize: 12,
              color: PdfBrandColors.inkSecondary,
            ),
            if (req.statementPeriodText.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                req.statementPeriodText,
                style: styles.text(size: 11.5, color: PdfBrandColors.inkSecondary),
                textDirection: textDirection,
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(height: 18),
    ],
  );
}

/// Default header row: app name on one side, generated-on stamp on the other.
pw.Widget _buildDefaultHeaderRow(_PdfRequest req, _PdfStyles styles) {
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
      _labelValueRow(
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

/// Premium branded header: merchant logo + store name/phone, with the
/// generated-on date positioned below.
///
/// Layout (LTR):  [Logo 48×48]  [Store Name / Phone]  ···  [Generated On]
/// Layout (RTL):  [Generated On]  ···  [Store Name / Phone]  [Logo 48×48]
///
/// If the merchant logo bytes are null (file missing/corrupt), renders text
/// only — the logo is gracefully omitted without visual breakage.
pw.Widget _buildBrandedHeaderRow(
  _PdfRequest req,
  _PdfStyles styles,
  pw.TextDirection textDirection,
) {
  // Build the merchant identity column (store name + optional phone).
  final merchantInfoChildren = <pw.Widget>[
    _pdfScriptAwareText(
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
        _pdfScriptAwareText(
          req.merchantStorePhone!,
          styles.text(size: 9, color: PdfBrandColors.inkSecondary),
          pageDirection: textDirection,
        ),
      );
  }

  final merchantInfo = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: merchantInfoChildren,
  );

  // Build the logo widget (if bytes are available).
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
      // Edge case: image bytes are corrupt or undecodable.
      // Fall back to text-only branding.
      logoWidget = null;
    }
  }

  // Assemble the leading side (logo + store info).
  final leadingChildren = <pw.Widget>[
    if (logoWidget != null) ...[
      logoWidget,
      pw.SizedBox(width: 12),
    ],
    pw.Expanded(child: merchantInfo),
  ];

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: <pw.Widget>[
      pw.Row(
        children: <pw.Widget>[
          ...leadingChildren,
          _labelValueRow(
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

// ============================================================================
// Premium footer — page numbers with brand accent
// ============================================================================

pw.Widget _buildFooter(_PdfRequest req, _PdfStyles styles, pw.Context context) {
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
          // Numerals + label as separate widgets for clean shaping.
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

// ============================================================================
// Body — currency sections with tables and summary cards
// ============================================================================

List<pw.Widget> _buildBody(
  _PdfRequest req,
  _PdfStyles styles,
  List<_CurrencySection> sections,
  pw.TextDirection textDirection,
) {
  return sections
      .asMap()
      .entries
      .expand((entry) {
        final section = entry.value;
        return <pw.Widget>[
          if (entry.key > 0) pw.SizedBox(height: PdfPremiumLayout.sectionGap),
          // Currency badge
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: PdfPremiumLayout.currencyBadgeDecoration(),
            child: _labelValueRow(
              styles: styles,
              label: req.labelCurrency,
              value: section.currencyCode,
              labelSize: 11,
              valueSize: 11,
              color: PdfBrandColors.inkOnLapis,
              emphasize: true,
            ),
          ),
          pw.SizedBox(height: 12),
          _buildTable(req, styles, section, textDirection),
          pw.SizedBox(height: PdfPremiumLayout.summaryTopBreathing),
          _buildSummaryCard(req, styles, section),
          pw.SizedBox(height: PdfPremiumLayout.summaryBottomBreathing),
        ];
      })
      .toList(growable: false);
}

// ============================================================================
// Premium transaction table
// ============================================================================

pw.Widget _buildTable(
  _PdfRequest req,
  _PdfStyles styles,
  _CurrencySection section,
  pw.TextDirection textDirection,
) {
  final headerStyle = styles.text(
    color: PdfBrandColors.inkOnLapis,
    emphasize: true,
  );

  final headerCells = <pw.Widget>[
    _cell(req.labelDate, headerStyle, alignment: _CellAlign.start),
    _cell(req.labelDetails, headerStyle, alignment: _CellAlign.start),
    _cell(req.labelDebt, headerStyle, alignment: _CellAlign.end),
    _cell(req.labelPayment, headerStyle, alignment: _CellAlign.end),
    _cell(req.labelRunningBalance, headerStyle, alignment: _CellAlign.end),
  ];

  final rows = <pw.TableRow>[
    // Header row — repeats on every page
    pw.TableRow(
      repeat: true,
      decoration: PdfPremiumLayout.headerRowDecoration(),
      children: req.isRtl
          ? headerCells.reversed.toList(growable: false)
          : headerCells,
    ),
    // Data rows — zebra-striped + thin colored side strip on the date cell
    // signals debt/payment without flooding the row with tinted backgrounds.
    ...section.rows.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;
      final isDebt = row.isDebt;
      final stripeColor = index.isEven ? PdfBrandColors.pearlStripe : PdfColors.white;
      final indicatorColor = isDebt ? PdfBrandColors.debt : PdfBrandColors.payment;

      final rowBaseStyle = styles.text(size: 9);
      final debtStyle = styles.text(
        size: 9,
        color: isDebt ? PdfBrandColors.debt : PdfBrandColors.inkSecondary,
        emphasize: isDebt,
      );
      final paymentStyle = styles.text(
        size: 9,
        color: !isDebt ? PdfBrandColors.payment : PdfBrandColors.inkSecondary,
        emphasize: !isDebt,
      );

      final cells = <pw.Widget>[
        _stripCell(
          row.date,
          rowBaseStyle,
          indicatorColor,
          textDirection,
        ),
        _detailsCell(styles, row),
        _cell(row.debt, debtStyle, alignment: _CellAlign.end),
        _cell(row.payment, paymentStyle, alignment: _CellAlign.end),
        _cell(row.runningBalance, rowBaseStyle, alignment: _CellAlign.end),
      ];

      final finalCells = req.isRtl
          ? cells.reversed.toList(growable: false)
          : cells;

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: stripeColor),
        children: finalCells,
      );
    }),
  ];

  final columnWidths = req.isRtl
      ? const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(4),
          4: pw.FlexColumnWidth(2),
        }
      : const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(4),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(2),
          4: pw.FlexColumnWidth(2),
        };

  return pw.Directionality(
    textDirection: req.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    child: pw.Table(
      border: PdfPremiumLayout.dataTableBorder,
      columnWidths: columnWidths,
      children: rows,
    ),
  );
}

enum _CellAlign { start, end }

pw.Widget _cell(
  String text,
  pw.TextStyle style, {
  required _CellAlign alignment,
}) {
  final align = alignment == _CellAlign.end
      ? pw.TextAlign.end
      : pw.TextAlign.start;
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

/// Item/category line (bold) + optional note (smaller, secondary) — keeps
/// narrative fields in one column for compact A4 layouts.
pw.Widget _detailsCell(_PdfStyles styles, _TxnRow row) {
  final title = row.itemTitleLine;
  final note = row.noteLine;
  final hasTitle = title.isNotEmpty;
  final hasNote = note.isNotEmpty;

  if (!hasTitle && !hasNote) {
    return _cell('-', styles.text(size: 9), alignment: _CellAlign.start);
  }

  final children = <pw.Widget>[];
  if (hasTitle) {
    children.add(
      pw.Text(
        title,
        style: styles.text(size: 9, emphasize: true),
        textAlign: pw.TextAlign.start,
      ),
    );
  }
  if (hasNote) {
    if (hasTitle) {
      children.add(pw.SizedBox(height: 2));
    }
    children.add(
      pw.Text(
        note,
        style: styles.text(
          size: hasTitle ? 8 : 9,
          color: hasTitle ? PdfBrandColors.inkSecondary : PdfBrandColors.inkPrimary,
          emphasize: !hasTitle,
        ),
        textAlign: pw.TextAlign.start,
        maxLines: 4,
      ),
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: children,
    ),
  );
}

/// Date cell with a 3px wide colored edge strip on the outer side of the table
/// (left in LTR, right in RTL) indicating debt vs payment.
pw.Widget _stripCell(
  String text,
  pw.TextStyle style,
  PdfColor indicatorColor,
  pw.TextDirection tableDirection,
) {
  final outerStrip = tableDirection == pw.TextDirection.rtl
      ? pw.Border(
          right: pw.BorderSide(color: indicatorColor, width: 3),
        )
      : pw.Border(
          left: pw.BorderSide(color: indicatorColor, width: 3),
        );
  return pw.Container(
    decoration: pw.BoxDecoration(border: outerStrip),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    child: pw.Text(
      text,
      style: style,
      textAlign: pw.TextAlign.start,
      maxLines: 2,
    ),
  );
}

// ============================================================================
// Premium summary card — color-coded net balance
// ============================================================================

pw.Widget _buildSummaryCard(
  _PdfRequest req,
  _PdfStyles styles,
  _CurrencySection section,
) {
  final isNegative = section.rawNetBalance < 0;
  final balanceColor = section.rawNetBalance == 0
      ? PdfBrandColors.inkPrimary
      : (isNegative ? PdfBrandColors.debt : PdfBrandColors.payment);

  return pw.Container(
    padding: PdfPremiumLayout.summaryCardPadding,
    decoration: PdfPremiumLayout.summaryCardDecoration(),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        _summaryRow(
          styles,
          req.labelTotalDebt,
          section.totalDebtValue,
          PdfBrandColors.debt,
        ),
        pw.SizedBox(height: 8),
        _summaryRow(
          styles,
          req.labelTotalPayment,
          section.totalPaymentValue,
          PdfBrandColors.payment,
        ),
        pw.SizedBox(height: 10),
        PdfPremiumLayout.hairlineDivider(color: PdfBrandColors.lapisBorderSoft),
        pw.SizedBox(height: 10),
        _summaryRow(
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

pw.Widget _summaryRow(
  _PdfStyles styles,
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

/// Renders `label: value` as TWO separate `pw.Text` widgets in a `pw.Row`,
/// so the label run (potentially Arabic) and the value run (potentially Latin)
/// never share a single `pw.Text` — each span is single-script and the
/// dart_pdf 3.12 fontFallback span-split bug cannot trigger.
pw.Widget _labelValueRow({
  required _PdfStyles styles,
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
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
      ),
    ],
  );
}

// ============================================================================
// Data processing — group by currency, compute running balances
// ============================================================================

List<_CurrencySection> _buildCurrencySections(_PdfRequest req) {
  final amountFmt = NumberFormat.decimalPattern(AppConstants.numeralLocale);
  final dateFmt = DateFormat.yMd(AppConstants.numeralLocale);
  final grouped = <String, List<_TxnInput>>{};

  for (final t in req.transactions) {
    grouped.putIfAbsent(t.currency, () => <_TxnInput>[]).add(t);
  }

  final sortedCodes = grouped.keys.toList()..sort();
  final sections = sortedCodes
      .map((code) {
        final txns = grouped[code]!
          // Primary key: transactionDate (the financial date the merchant claims).
          // Tie-breaker: createdAt (insertion order) — so two transactions on the
          // same calendar day always running-balance in the order they were
          // recorded, not the order they happen to come out of the iteration.
          ..sort((a, b) {
            final c = a.transactionDate.compareTo(b.transactionDate);
            return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
          });

        var runningBalance = 0;
        var totalDebt = 0;
        var totalPayment = 0;

        final rows = txns
            .map((t) {
              final isDebt = t.type == TransactionType.debt;
              if (isDebt) {
                totalDebt += t.amount;
                runningBalance -= t.amount;
              } else {
                totalPayment += t.amount;
                runningBalance += t.amount;
              }

              final sanitizedItemName = _sanitizePdfText(
                t.itemName ?? '',
              ).trim();
              final sanitizedDescription = _sanitizePdfText(
                t.description ?? '',
              ).trim();

              return _TxnRow(
                date: _sanitizePdfText(dateFmt.format(t.transactionDate)),
                itemTitleLine: sanitizedItemName,
                noteLine: sanitizedDescription,
                debt: isDebt ? _fmtAmount(amountFmt, t.amount, code) : '-',
                payment: isDebt ? '-' : _fmtAmount(amountFmt, t.amount, code),
                runningBalance: _fmtAmount(amountFmt, runningBalance, code),
                isDebt: isDebt,
              );
            })
            .toList(growable: false);

        final net = totalPayment - totalDebt;
        final sanitizedCurrencyCode = _sanitizePdfText(code).trim();
        return _CurrencySection(
          currencyCode: sanitizedCurrencyCode,
          totalDebtValue: _fmtAmount(
            amountFmt,
            totalDebt,
            sanitizedCurrencyCode,
          ),
          totalPaymentValue: _fmtAmount(
            amountFmt,
            totalPayment,
            sanitizedCurrencyCode,
          ),
          netBalanceValue: _fmtAmount(amountFmt, net, sanitizedCurrencyCode),
          rawNetBalance: net,
          rows: rows,
        );
      })
      .toList(growable: false);

  if (sections.isNotEmpty) return sections;

  // Fallback when no transactions exist
  final sanitizedFallbackCurrencyCode = _sanitizePdfText(
    req.fallbackCurrencyCode,
  ).trim();
  return <_CurrencySection>[
    _CurrencySection(
      currencyCode: sanitizedFallbackCurrencyCode,
      totalDebtValue: _fmtAmount(
        amountFmt,
        req.fallbackTotalDebt,
        sanitizedFallbackCurrencyCode,
      ),
      totalPaymentValue: _fmtAmount(
        amountFmt,
        req.fallbackTotalPayment,
        sanitizedFallbackCurrencyCode,
      ),
      netBalanceValue: _fmtAmount(
        amountFmt,
        req.fallbackNetBalance,
        sanitizedFallbackCurrencyCode,
      ),
      rawNetBalance: req.fallbackNetBalance,
      rows: const <_TxnRow>[],
    ),
  ];
}

String _fmtAmount(NumberFormat fmt, int amount, String currency) {
  final sanitizedCurrency = _sanitizePdfText(currency).trim();
  final formattedAmount = MoneyUtil.formatMinorUnitsForCode(
    amount,
    sanitizedCurrency.isEmpty ? currency : sanitizedCurrency,
  );
  final formatted = sanitizedCurrency.isEmpty
      ? formattedAmount
      : '$formattedAmount $sanitizedCurrency';
  return _sanitizePdfText(formatted);
}

/// True when [text] contains any Arabic-script codepoint (main block + extensions).
bool _containsArabicScript(String text) {
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

/// Resolves per-run [pw.TextDirection] so Arabic shapes/connects in an LTR page.
pw.TextDirection _pdfRunTextDirection(
  String text, {
  required pw.TextDirection pageDirection,
}) {
  if (_containsArabicScript(text)) {
    return pw.TextDirection.rtl;
  }
  return pageDirection;
}

/// Renders [raw] with Cairo + optional RTL [pw.Directionality] when the run is Arabic.
pw.Widget _pdfScriptAwareText(
  String raw,
  pw.TextStyle style, {
  required pw.TextDirection pageDirection,
  pw.TextAlign textAlign = pw.TextAlign.start,
  int? maxLines,
}) {
  final text = _sanitizePdfText(raw);
  final runDirection = _pdfRunTextDirection(
    text,
    pageDirection: pageDirection,
  );
  final child = pw.Text(
    text,
    style: style,
    textDirection: runDirection,
    textAlign: textAlign,
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

String _sanitizePdfText(String input) {
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

// ============================================================================
// Data transfer objects — reconstructed inside the isolate from spawn-safe
// maps and lists.
// ============================================================================

final class _PdfRequest {
  const _PdfRequest({
    required this.applicationName,
    required this.localeTag,
    required this.isRtl,
    required this.regularFontBytes,
    required this.boldFontBytes,
    required this.fallbackRegularFontBytes,
    required this.fallbackBoldFontBytes,
    required this.titleStatement,
    required this.labelContactName,
    required this.labelGeneratedOn,
    required this.labelTotalDebt,
    required this.labelTotalPayment,
    required this.labelNetBalance,
    required this.labelDate,
    required this.labelDetails,
    required this.labelDebt,
    required this.labelPayment,
    required this.labelRunningBalance,
    required this.labelCurrency,
    required this.labelPage,
    required this.contactName,
    required this.generatedOnValue,
    required this.statementPeriodText,
    required this.fallbackCurrencyCode,
    required this.fallbackTotalDebt,
    required this.fallbackTotalPayment,
    required this.fallbackNetBalance,
    required this.transactions,
    required this.msgPreparing,
    required this.msgGrouping,
    required this.msgBuilding,
    required this.msgRendering,
    this.merchantStoreName,
    this.merchantStorePhone,
    this.merchantLogoBytes,
  });

  factory _PdfRequest.fromMap(Map<String, Object?> map) {
    final rawTransactions = _requiredValue<List<Map<String, Object?>>>(
      map,
      'transactions',
    );

    return _PdfRequest(
      applicationName: _sanitizePdfText(
        _requiredValue<String>(map, 'applicationName'),
      ),
      localeTag: _requiredValue<String>(map, 'localeTag'),
      isRtl: _requiredValue<bool>(map, 'isRtl'),
      regularFontBytes: _requiredValue<Uint8List>(map, 'regularFontBytes'),
      boldFontBytes: _requiredValue<Uint8List>(map, 'boldFontBytes'),
      fallbackRegularFontBytes: _requiredValue<Uint8List>(
        map,
        'fallbackRegularFontBytes',
      ),
      fallbackBoldFontBytes: _requiredValue<Uint8List>(
        map,
        'fallbackBoldFontBytes',
      ),
      titleStatement: _sanitizePdfText(
        _requiredValue<String>(map, 'titleStatement'),
      ),
      labelContactName: _sanitizePdfText(
        _requiredValue<String>(map, 'labelContactName'),
      ),
      labelGeneratedOn: _sanitizePdfText(
        _requiredValue<String>(map, 'labelGeneratedOn'),
      ),
      labelTotalDebt: _sanitizePdfText(
        _requiredValue<String>(map, 'labelTotalDebt'),
      ),
      labelTotalPayment: _sanitizePdfText(
        _requiredValue<String>(map, 'labelTotalPayment'),
      ),
      labelNetBalance: _sanitizePdfText(
        _requiredValue<String>(map, 'labelNetBalance'),
      ),
      labelDate: _sanitizePdfText(_requiredValue<String>(map, 'labelDate')),
      labelDetails: _sanitizePdfText(
        _requiredValue<String>(map, 'labelDetails'),
      ),
      labelDebt: _sanitizePdfText(_requiredValue<String>(map, 'labelDebt')),
      labelPayment: _sanitizePdfText(
        _requiredValue<String>(map, 'labelPayment'),
      ),
      labelRunningBalance: _sanitizePdfText(
        _requiredValue<String>(map, 'labelRunningBalance'),
      ),
      labelCurrency: _sanitizePdfText(
        _requiredValue<String>(map, 'labelCurrency'),
      ),
      labelPage: _sanitizePdfText(_requiredValue<String>(map, 'labelPage')),
      contactName: _sanitizePdfText(_requiredValue<String>(map, 'contactName')),
      generatedOnValue: _sanitizePdfText(
        _requiredValue<String>(map, 'generatedOnValue'),
      ),
      statementPeriodText: _sanitizePdfText(
        (map['statementPeriodText'] as String?) ?? '',
      ),
      fallbackCurrencyCode: _sanitizePdfText(
        _requiredValue<String>(map, 'fallbackCurrencyCode'),
      ).trim(),
      fallbackTotalDebt: _requiredValue<int>(map, 'fallbackTotalDebt'),
      fallbackTotalPayment: _requiredValue<int>(map, 'fallbackTotalPayment'),
      fallbackNetBalance: _requiredValue<int>(map, 'fallbackNetBalance'),
      transactions: rawTransactions
          .map(_TxnInput.fromMap)
          .toList(growable: false),
      msgPreparing: _sanitizePdfText(
        _requiredValue<String>(map, 'msgPreparing'),
      ),
      msgGrouping: _sanitizePdfText(_requiredValue<String>(map, 'msgGrouping')),
      msgBuilding: _sanitizePdfText(_requiredValue<String>(map, 'msgBuilding')),
      msgRendering: _sanitizePdfText(
        _requiredValue<String>(map, 'msgRendering'),
      ),
      merchantStoreName: map['merchantStoreName'] as String?,
      merchantStorePhone: map['merchantStorePhone'] as String?,
      merchantLogoBytes: map['merchantLogoBytes'] as Uint8List?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'applicationName': _sanitizePdfText(applicationName),
      'localeTag': localeTag,
      'isRtl': isRtl,
      'regularFontBytes': regularFontBytes,
      'boldFontBytes': boldFontBytes,
      'fallbackRegularFontBytes': fallbackRegularFontBytes,
      'fallbackBoldFontBytes': fallbackBoldFontBytes,
      'titleStatement': _sanitizePdfText(titleStatement),
      'labelContactName': _sanitizePdfText(labelContactName),
      'labelGeneratedOn': _sanitizePdfText(labelGeneratedOn),
      'labelTotalDebt': _sanitizePdfText(labelTotalDebt),
      'labelTotalPayment': _sanitizePdfText(labelTotalPayment),
      'labelNetBalance': _sanitizePdfText(labelNetBalance),
      'labelDate': _sanitizePdfText(labelDate),
      'labelDetails': _sanitizePdfText(labelDetails),
      'labelDebt': _sanitizePdfText(labelDebt),
      'labelPayment': _sanitizePdfText(labelPayment),
      'labelRunningBalance': _sanitizePdfText(labelRunningBalance),
      'labelCurrency': _sanitizePdfText(labelCurrency),
      'labelPage': _sanitizePdfText(labelPage),
      'contactName': _sanitizePdfText(contactName),
      'generatedOnValue': _sanitizePdfText(generatedOnValue),
      'statementPeriodText': _sanitizePdfText(statementPeriodText),
      'fallbackCurrencyCode': _sanitizePdfText(fallbackCurrencyCode).trim(),
      'fallbackTotalDebt': fallbackTotalDebt,
      'fallbackTotalPayment': fallbackTotalPayment,
      'fallbackNetBalance': fallbackNetBalance,
      'transactions': transactions
          .map((txn) => txn.toMap())
          .toList(
            growable: false,
          ),
      'msgPreparing': _sanitizePdfText(msgPreparing),
      'msgGrouping': _sanitizePdfText(msgGrouping),
      'msgBuilding': _sanitizePdfText(msgBuilding),
      'msgRendering': _sanitizePdfText(msgRendering),
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

  /// Inter font bytes — defensive Latin/punctuation fallback for Cairo.
  final Uint8List fallbackRegularFontBytes;
  final Uint8List fallbackBoldFontBytes;

  final String titleStatement;
  final String labelContactName;
  final String labelGeneratedOn;
  final String labelTotalDebt;
  final String labelTotalPayment;
  final String labelNetBalance;
  final String labelDate;
  final String labelDetails;
  final String labelDebt;
  final String labelPayment;
  final String labelRunningBalance;
  final String labelCurrency;
  final String labelPage;

  final String contactName;
  final String generatedOnValue;
  final String statementPeriodText;
  final String fallbackCurrencyCode;
  final int fallbackTotalDebt;
  final int fallbackTotalPayment;
  final int fallbackNetBalance;
  final List<_TxnInput> transactions;
  final String msgPreparing;
  final String msgGrouping;
  final String msgBuilding;
  final String msgRendering;

  /// Optional merchant branding fields — populated when a [MerchantProfile]
  /// is provided. All three are null when no branding is active.
  final String? merchantStoreName;
  final String? merchantStorePhone;
  final Uint8List? merchantLogoBytes;
}

final class _CurrencySection {
  const _CurrencySection({
    required this.currencyCode,
    required this.totalDebtValue,
    required this.totalPaymentValue,
    required this.netBalanceValue,
    required this.rawNetBalance,
    required this.rows,
  });

  final String currencyCode;
  final String totalDebtValue;
  final String totalPaymentValue;
  final String netBalanceValue;
  final int rawNetBalance;
  final List<_TxnRow> rows;
}

final class _TxnRow {
  const _TxnRow({
    required this.date,
    required this.itemTitleLine,
    required this.noteLine,
    required this.debt,
    required this.payment,
    required this.runningBalance,
    required this.isDebt,
  });

  final String date;
  final String itemTitleLine;
  final String noteLine;
  final String debt;
  final String payment;
  final String runningBalance;
  final bool isDebt;
}

final class _TxnInput {
  const _TxnInput({
    required this.currency,
    required this.amount,
    required this.itemName,
    required this.description,
    required this.transactionDate,
    required this.createdAt,
    required this.type,
  });

  factory _TxnInput.fromMap(Map<String, Object?> map) {
    final itemNameValue = map['itemName'];
    final String? itemName;
    if (itemNameValue == null) {
      itemName = null;
    } else if (itemNameValue is String) {
      itemName = _sanitizePdfText(itemNameValue);
    } else {
      throw const FormatException(
        'Expected "itemName" to be a String or null',
      );
    }

    final descriptionValue = map['description'];
    final description = descriptionValue == null
        ? null
        : descriptionValue is String
        ? _sanitizePdfText(descriptionValue)
        : throw const FormatException(
            'Expected "description" to be a String or null',
          );
    final typeName = _requiredValue<String>(map, 'type');

    return _TxnInput(
      currency: _sanitizePdfText(
        _requiredValue<String>(map, 'currency'),
      ).trim(),
      amount: _requiredValue<int>(map, 'amount'),
      itemName: itemName,
      description: description,
      transactionDate: DateTime.parse(
        _requiredValue<String>(map, 'transactionDate'),
      ),
      createdAt: DateTime.parse(_requiredValue<String>(map, 'createdAt')),
      type: switch (typeName) {
        'debt' => TransactionType.debt,
        'payment' => TransactionType.payment,
        _ => throw FormatException('Unknown transaction type: $typeName'),
      },
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'currency': _sanitizePdfText(currency).trim(),
      'amount': amount,
      'itemName': itemName == null ? null : _sanitizePdfText(itemName!),
      'description': description == null
          ? null
          : _sanitizePdfText(description!),
      'transactionDate': transactionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'type': type.name,
    };
  }

  final String currency;
  final int amount;
  final String? itemName;
  final String? description;
  final DateTime transactionDate;
  final DateTime createdAt;
  final TransactionType type;
}

T _requiredValue<T>(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is T) {
    return value;
  }
  final typeDescription = T.toString();
  throw FormatException('Expected "$key" to be $typeDescription');
}

final class _ProgressMsg {
  const _ProgressMsg(this.progress, this.message);

  final double progress;
  final String message;
}

final class _ErrorMsg {
  const _ErrorMsg(this.error, this.stackTrace);

  final String error;
  final String stackTrace;
}
