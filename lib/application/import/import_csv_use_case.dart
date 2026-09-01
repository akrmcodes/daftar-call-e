import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/core/utils/csv_parser.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/core/utils/whatsapp_util.dart';
import 'package:daftar/domain/entities/audit_log.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/duplicate_resolution_strategy.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/bulk_write_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/csv_bulk_persist_batch.dart';
import 'package:fpdart/fpdart.dart';

/// Canonical CSV column identifiers after header normalization (English or Arabic
/// synonyms map into these tokens).
abstract final class CsvImportColumn {
  static const String nameKey = 'name';
  static const String phoneKey = 'phone';
  static const String amountKey = 'amount';
  static const String typeKey = 'type';
  static const String currencyKey = 'currency';
  static const String dateKey = 'date';
  static const String descriptionKey = 'description';
  static const String itemNameKey = 'itemName';

  /// Expected header labels (conceptual schema):
  ///
  /// `Name`, `Phone`, `Amount`, `Type`, `Currency`, `Date`, `Description`.
  ///
  /// `Phone` / `Description` may be omitted for some rows — new contacts still
  /// require a display [nameKey]. Synonyms listed in `_headerSynonyms`.
  static const List<String> requiredImportFields = <String>[
    nameKey,
    amountKey,
    typeKey,
    currencyKey,
    dateKey,
  ];

  static const List<String> optionalImportFields = <String>[
    phoneKey,
    descriptionKey,
    itemNameKey,
  ];
}

/// Summary returned to the presentation layer after a CSV import finishes.
///
/// Rows that fail validation or repository checks are counted in [failureCount]
/// and enumerated in [errors].
final class CsvImportResult {
  /// Builds a summarized report for bulk CSV imports.
  const CsvImportResult({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.errors,
    this.skippedDuplicateRows = 0,
  });

  /// Rows evaluated after the header (includes failures).
  final int totalRows;

  /// Transactions successfully persisted.
  final int successCount;

  /// Rows skipped because of malformed data or business failures.
  final int failureCount;

  /// Rows omitted because they matched existing contacts while
  /// [DuplicateResolutionStrategy.skip] was selected.
  final int skippedDuplicateRows;

  /// Diagnostic messages like `Row 4: Amount is invalid.`
  final List<String> errors;
}

/// Returned by [ImportCsvUseCase.analyzeImport] — DB read + in-memory categorization only.
final class CsvPreFlightSummary {
  const CsvPreFlightSummary({
    required this.newContactsCount,
    required this.duplicateContactsCount,
    required this.validRowsCount,
  });

  /// Distinct contacts that must be created to import valid rows into new accounts.
  final int newContactsCount;

  /// Distinct ledger contacts matched by ≥1 row (would merge or skip depending on strategy).
  final int duplicateContactsCount;

  /// Valid CSV body rows counted after field checks (ambiguous name matches excluded).
  final int validRowsCount;
}

/// Loads contacts / transactions exported as CSV via offline tooling.
///
/// Raw CSV bytes are decoded and split in [CsvParserUtil.parseCsvBytesStructured] (worker
/// isolate). This use case maps columns, validates business rules, and writes
/// contacts / transactions through existing use cases.
///
/// Failures surfaced as `Left`:
/// - [ValidationFailure]: missing mutually exclusive CSV source, malformed
///   parameters, unreadable ledger id, absent required CSV columns.
/// - [DatabaseFailure]: unexpected failure from [CsvParserUtil.parseCsvBytesStructured].
/// - [StorageFailure]: path-based reads that cannot finish.
///
/// Partial success yields `Right` [CsvImportResult] even when failures exist.
///
/// Rows may fail with granular reasons recorded in [CsvImportResult.errors]
/// while other rows succeed.
final class ImportCsvUseCase {
  const ImportCsvUseCase({
    required ContactRepository contactRepository,
    required LedgerRepository ledgerRepository,
    required TransactionRepository transactionRepository,
    required BulkWriteRepository bulkWriteRepository,
    required ActivationRepository activationRepository,
  })  : _contactRepository = contactRepository,
        _ledgerRepository = ledgerRepository,
        _transactionRepository = transactionRepository,
        _bulkWriteRepository = bulkWriteRepository,
        _activationRepository = activationRepository;

  static const Map<String, String> _headerSynonyms = {
    // Name
    'name': CsvImportColumn.nameKey,
    'full name': CsvImportColumn.nameKey,
    'contact': CsvImportColumn.nameKey,
    'الاسم': CsvImportColumn.nameKey,
    'الإسم': CsvImportColumn.nameKey,

    // Phone
    'phone': CsvImportColumn.phoneKey,
    'mobile': CsvImportColumn.phoneKey,
    'cell': CsvImportColumn.phoneKey,
    'tel': CsvImportColumn.phoneKey,
    'الهاتف': CsvImportColumn.phoneKey,
    'جوال': CsvImportColumn.phoneKey,
    'الجوال': CsvImportColumn.phoneKey,

    // Amount
    'amount': CsvImportColumn.amountKey,
    'value': CsvImportColumn.amountKey,
    'المبلغ': CsvImportColumn.amountKey,
    'مبلغ': CsvImportColumn.amountKey,

    // Type
    'type': CsvImportColumn.typeKey,
    'kind': CsvImportColumn.typeKey,
    'النوع': CsvImportColumn.typeKey,

    // Currency
    'currency': CsvImportColumn.currencyKey,
    'curr': CsvImportColumn.currencyKey,
    'ccy': CsvImportColumn.currencyKey,
    'العملة': CsvImportColumn.currencyKey,
    'عملة': CsvImportColumn.currencyKey,

    // Date
    'date': CsvImportColumn.dateKey,
    'dt': CsvImportColumn.dateKey,
    'التاريخ': CsvImportColumn.dateKey,

    // Description
    'description': CsvImportColumn.descriptionKey,
    'memo': CsvImportColumn.descriptionKey,
    'note': CsvImportColumn.descriptionKey,
    'notes': CsvImportColumn.descriptionKey,
    'البيان': CsvImportColumn.descriptionKey,
    'الوصف': CsvImportColumn.descriptionKey,

    // Item name
    'item name': CsvImportColumn.itemNameKey,
    'item': CsvImportColumn.itemNameKey,
    'product': CsvImportColumn.itemNameKey,
    'goods': CsvImportColumn.itemNameKey,
    'الصنف': CsvImportColumn.itemNameKey,
    'صنف': CsvImportColumn.itemNameKey,
    'اسم الصنف': CsvImportColumn.itemNameKey,
    'الصنف/البضاعة': CsvImportColumn.itemNameKey,
  };

  final ContactRepository _contactRepository;
  final LedgerRepository _ledgerRepository;
  final TransactionRepository _transactionRepository;
  final BulkWriteRepository _bulkWriteRepository;
  final ActivationRepository _activationRepository;

  static const List<String> _defaultAvatarColors = [
    '#5C6BC0',
    '#26A69A',
    '#EF5350',
    '#AB47BC',
    '#42A5F5',
    '#FFA726',
    '#66BB6A',
    '#EC407A',
    '#8D6E63',
    '#78909C',
  ];

  /// Suggested CSV column index per canonical [CsvImportColumn] token — first
  /// synonym match wins when duplicates appear.
  static Map<String, int> suggestColumnIndices(List<String> rawHeaders) {
    final accumulator = <String, int>{};
    for (var ordinal = 0; ordinal < rawHeaders.length; ordinal++) {
      final resolvedKey =
          ImportCsvUseCase._resolveHeaderSynonym(rawHeaders[ordinal]);
      if (resolvedKey == null) {
        continue;
      }
      accumulator.putIfAbsent(resolvedKey, () => ordinal);
    }
    return accumulator;
  }

  /// Phase 1 — reads [ContactRepository] once, builds in-memory phone/name
  /// indexes, and categorizes each valid row without writes.
  ///
  /// Returns the same [Failure] subtypes as [execute] when parsing or mapping
  /// cannot proceed.
  Future<Either<Failure, CsvPreFlightSummary>> analyzeImport({
    required String ledgerId,
    Uint8List? csvBytes,
    String? csvPath,
    Map<String, int>? columnIndicesByCanonicalField,
    CsvDecodingMode decodingMode = CsvDecodingMode.auto,
    CsvStructuralParseOutput? preParsedStructural,
  }) async {
    final prepared = await _prepareCsvImportContext(
      ledgerId: ledgerId,
      csvBytes: csvBytes,
      csvPath: csvPath,
      columnIndicesByCanonicalField: columnIndicesByCanonicalField,
      decodingMode: decodingMode,
      preParsedStructural: preParsedStructural,
    );
    if (prepared.isLeft()) {
      return Left(prepared.getLeft().toNullable()!);
    }
    final ctx = prepared.getRight().toNullable()!;

    final summary = await Isolate.run(
      () => _analyzeImportSync(
        bodyRows: ctx.bodyRows,
        headerBacking: ctx.headerLookup.headerBacking,
        seedContacts: ctx.seedContacts,
      ),
    );

    return Right(summary);
  }

  /// Imports every well-formed row contained in either [csvBytes] or [csvPath].
  ///
  /// Supply **exactly one** CSV payload source.
  ///
  /// When [columnIndicesByCanonicalField] is non-null and non-empty, header
  /// detection uses these mapped indices instead of synonym guessing over the
  /// header row.
  ///
  /// [decodingMode] controls CSV byte decoding before row splitting (see
  /// [CsvParserUtil.parseCsvBytesStructured]).
  ///
  /// [duplicateStrategy] controls rows that match existing contacts (by phone
  /// or unique name): [DuplicateResolutionStrategy.merge] posts transactions to
  /// the matched contact; [DuplicateResolutionStrategy.skip] omits them and
  /// increments [CsvImportResult.skippedDuplicateRows].
  Future<Either<Failure, CsvImportResult>> execute({
    required String ledgerId,
    required DuplicateResolutionStrategy duplicateStrategy,
    Uint8List? csvBytes,
    String? csvPath,
    Map<String, int>? columnIndicesByCanonicalField,
    CsvDecodingMode decodingMode = CsvDecodingMode.auto,
    CsvStructuralParseOutput? preParsedStructural,
  }) async {
    final prepared = await _prepareCsvImportContext(
      ledgerId: ledgerId,
      csvBytes: csvBytes,
      csvPath: csvPath,
      columnIndicesByCanonicalField: columnIndicesByCanonicalField,
      decodingMode: decodingMode,
      preParsedStructural: preParsedStructural,
    );
    if (prepared.isLeft()) {
      return Left(prepared.getLeft().toNullable()!);
    }
    final ctx = prepared.getRight().toNullable()!;

    final activeContactCountResult = await _contactRepository.getActiveCount();
    if (activeContactCountResult.isLeft()) {
      return Left(activeContactCountResult.getLeft().toNullable()!);
    }
    final activeTransactionCountResult =
        await _transactionRepository.getActiveCount();
    if (activeTransactionCountResult.isLeft()) {
      return Left(activeTransactionCountResult.getLeft().toNullable()!);
    }

    final entitlement =
        (await _activationRepository.getEntitlement()).effective;
    final batchNow = DateTime.now().toUtc();
    final totalRowsEvaluated = ctx.bodyRows.length;

    final buildResult = await Isolate.run(
      () => _buildEntitiesSync(
        bodyRows: ctx.bodyRows,
        headerBacking: ctx.headerLookup.headerBacking,
        seedContacts: ctx.seedContacts,
        ledgerId: ctx.ledgerId,
        duplicateStrategy: duplicateStrategy,
        activeContactCount:
            activeContactCountResult.getRight().toNullable()!,
        activeTransactionCount:
            activeTransactionCountResult.getRight().toNullable()!,
        entitlement: entitlement,
        batchNow: batchNow,
      ),
    );

    if (buildResult.batchContacts.isNotEmpty ||
        buildResult.batchTransactions.isNotEmpty) {
      final persistResult = await _bulkWriteRepository.persist(
        CsvBulkPersistBatch(
          contacts: buildResult.batchContacts,
          transactions: buildResult.batchTransactions,
          auditLogs: buildResult.batchAuditLogs,
        ),
      );
      if (persistResult.isLeft()) {
        return Left(persistResult.getLeft().toNullable()!);
      }
    }

    return Right(
      CsvImportResult(
        totalRows: totalRowsEvaluated,
        successCount: buildResult.successCount,
        failureCount: buildResult.rowErrors.length,
        errors: List.unmodifiable(buildResult.rowErrors),
        skippedDuplicateRows: buildResult.skippedDuplicates,
      ),
    );
  }

  Future<Either<Failure, _PreparedCsvImportContext>> _prepareCsvImportContext({
    required String ledgerId,
    Uint8List? csvBytes,
    String? csvPath,
    Map<String, int>? columnIndicesByCanonicalField,
    CsvDecodingMode decodingMode = CsvDecodingMode.auto,
    CsvStructuralParseOutput? preParsedStructural,
  }) async {
    final normalizedLedgerId = ledgerId.trim();
    if (normalizedLedgerId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Ledger id is required.',
          code: 'csv_import_ledger_missing',
        ),
      );
    }

    final providesBytes = csvBytes != null;
    final providesPath = csvPath != null && csvPath.trim().isNotEmpty;
    if (providesBytes == providesPath) {
      return const Left(
        ValidationFailure(
          'Provide exactly one of csvBytes or csvPath.',
          code: 'csv_import_source_exclusive',
        ),
      );
    }

    final ledgerEither = await _ledgerRepository.getById(normalizedLedgerId);
    if (ledgerEither.isLeft()) {
      return Left(ledgerEither.getLeft().toNullable()!);
    }

    CsvStructuralParseOutput structural;
    if (preParsedStructural != null) {
      structural = preParsedStructural;
    } else {
      Uint8List rawBytes;

      try {
        if (providesBytes) {
          rawBytes = Uint8List.fromList(csvBytes);
        } else {
          rawBytes = await File(csvPath!.trim()).readAsBytes();
        }
      } on Object {
        return const Left(
          StorageFailure(
            'Could not read the CSV payload.',
            code: 'csv_import_read_failed',
          ),
        );
      }

      try {
        structural = await CsvParserUtil.parseCsvBytesStructured(
          rawBytes,
          decodingMode: decodingMode,
        );
      } on FormatException catch (e) {
        return Left(
          ValidationFailure(
            e.message,
            code: 'csv_import_parse_failed',
          ),
        );
      } on Object {
        return const Left(
          DatabaseFailure(
            'CSV parse worker failed unexpectedly.',
            code: 'csv_import_parse_worker_failed',
          ),
        );
      }
    }

    if (structural.isFatal || structural.headers.isEmpty) {
      return Left(
        ValidationFailure(
          structural.fatalMessage ?? 'CSV structure is unusable.',
          code: 'csv_import_structure_fatal',
        ),
      );
    }

    final Either<Failure, HeaderIndexLookup> columnIndex;
    final manualMap = columnIndicesByCanonicalField;
    if (manualMap != null && manualMap.isNotEmpty) {
      columnIndex = _validateManualColumnMap(
        manual: manualMap,
        headerColumnCount: structural.headers.length,
        ledgerDiagnostic: normalizedLedgerId,
      );
    } else {
      columnIndex = _mapHeaderIndexes(
        structural.headers,
        normalizedLedgerId,
      );
    }
    if (columnIndex.isLeft()) {
      return Left(columnIndex.getLeft().toNullable()!);
    }

    final headerLookup = columnIndex.getRight().toNullable()!;

    final contactsEither =
        await _contactRepository.getByLedger(normalizedLedgerId);
    if (contactsEither.isLeft()) {
      return Left(contactsEither.getLeft().toNullable()!);
    }

    final seedContacts = contactsEither.getRight().toNullable()!;

    return Right(
      _PreparedCsvImportContext(
        ledgerId: normalizedLedgerId,
        headerLookup: headerLookup,
        bodyRows: structural.bodyRows,
        seedContacts: seedContacts,
      ),
    );
  }

  static _ValidatedImportRowParse? _parseValidatedImportRow({
    required List<String> rowCells,
    required Map<String, int> headerBacking,
    required int spreadsheetRowNumber,
  }) {
    final nameCell =
        HeaderIndexLookup.pickCsvField(rowCells, headerBacking, CsvImportColumn.nameKey).trim();

    final phoneSanitized = WhatsAppUtil.sanitizePhone(
      HeaderIndexLookup.pickCsvField(rowCells, headerBacking, CsvImportColumn.phoneKey),
    );

    final typeLabel = CsvParserUtil.parseTransactionType(
      HeaderIndexLookup.pickCsvField(rowCells, headerBacking, CsvImportColumn.typeKey),
    );

    final currencyCandidate = HeaderIndexLookup.pickCsvField(
      rowCells,
      headerBacking,
      CsvImportColumn.currencyKey,
    ).trim();
    final amountRaw = HeaderIndexLookup.pickCsvField(
      rowCells,
      headerBacking,
      CsvImportColumn.amountKey,
    ).trim();

    final rowDateParsed = CsvParserUtil.parseCsvDate(
      HeaderIndexLookup.pickCsvField(rowCells, headerBacking, CsvImportColumn.dateKey),
    );

    final descriptionCell = HeaderIndexLookup.pickCsvField(
      rowCells,
      headerBacking,
      CsvImportColumn.descriptionKey,
    ).trim();

    final itemNameCell = HeaderIndexLookup.pickCsvField(
      rowCells,
      headerBacking,
      CsvImportColumn.itemNameKey,
    ).trim();

    if (nameCell.isEmpty &&
        phoneSanitized.isEmpty &&
        amountRaw.isEmpty &&
        currencyCandidate.isEmpty) {
      return null;
    }

    if (nameCell.isEmpty) {
      return _ValidatedImportRowParse.error(
        'Row $spreadsheetRowNumber: Name is required.',
      );
    }

    if (currencyCandidate.isEmpty) {
      return _ValidatedImportRowParse.error(
        'Row $spreadsheetRowNumber: Currency column is missing or blank.',
      );
    }

    final amountParsed = CsvParserUtil.parseAmountToMinorUnits(
      amountRaw,
      currencyCandidate,
    );
    if (amountParsed == null) {
      return _ValidatedImportRowParse.error(
        'Row $spreadsheetRowNumber: Amount is invalid.',
      );
    }
    if (amountParsed <= 0) {
      return _ValidatedImportRowParse.error(
        'Row $spreadsheetRowNumber: Amount must be greater than zero.',
      );
    }

    if (typeLabel == null) {
      return _ValidatedImportRowParse.error(
        'Row $spreadsheetRowNumber: Type must be Debt or Payment '
        '(supports Arabic synonyms).',
      );
    }

    if (rowDateParsed == null) {
      return _ValidatedImportRowParse.error(
        'Row $spreadsheetRowNumber: Date is missing or unrecognized.',
      );
    }

    return _ValidatedImportRowParse.ok(
      _CsvValidatedRowData(
        nameCell: nameCell,
        phoneSanitized: phoneSanitized,
        amountMinor: amountParsed,
        currency: currencyCandidate.trim().toUpperCase(),
        type: typeLabel,
        transactionDate: rowDateParsed,
        description: descriptionCell,
        itemName: itemNameCell,
      ),
    );
  }

  static String _newContactIdentityKey(String nameRaw, String phoneSanitized) =>
      '${normalizedName(nameRaw)}\u0000$phoneSanitized';

  Either<Failure, HeaderIndexLookup> _validateManualColumnMap({
    required Map<String, int> manual,
    required int headerColumnCount,
    required String ledgerDiagnostic,
  }) {
    final backing = <String, int>{};

    const requiredCsvHeaders = <String>{
      CsvImportColumn.nameKey,
      CsvImportColumn.amountKey,
      CsvImportColumn.typeKey,
      CsvImportColumn.currencyKey,
      CsvImportColumn.dateKey,
    };

    for (final canonical in requiredCsvHeaders) {
      final idx = manual[canonical];
      if (idx == null || idx < 0 || idx >= headerColumnCount) {
        return Left(
          ValidationFailure(
            'Invalid or missing column mapping for "$canonical" '
            '(ledger $ledgerDiagnostic).',
            code: 'csv_import_manual_map_invalid_$canonical',
          ),
        );
      }
      backing[canonical] = idx;
    }

    const optionalKeys = <String>{
      CsvImportColumn.phoneKey,
      CsvImportColumn.descriptionKey,
      CsvImportColumn.itemNameKey,
    };

    for (final canonical in optionalKeys) {
      final idx = manual[canonical];
      if (idx != null && idx >= 0 && idx < headerColumnCount) {
        backing[canonical] = idx;
      }
    }

    return Right(HeaderIndexLookup(backing));
  }

  Either<Failure, HeaderIndexLookup> _mapHeaderIndexes(
    List<String> rawHeaders,
    String ledgerDiagnostic,
  ) {
    final accumulator = <String, int>{};

    for (var columnOrdinal = 0;
        columnOrdinal < rawHeaders.length;
        columnOrdinal++) {
      final resolvedKey =
          ImportCsvUseCase._resolveHeaderSynonym(rawHeaders[columnOrdinal]);
      if (resolvedKey == null) {
        continue;
      }

      accumulator[resolvedKey] = columnOrdinal;
    }

    const requiredCsvHeaders = <String>{
      CsvImportColumn.nameKey,
      CsvImportColumn.amountKey,
      CsvImportColumn.typeKey,
      CsvImportColumn.currencyKey,
      CsvImportColumn.dateKey,
    };

    for (final canonical in requiredCsvHeaders) {
      if (!accumulator.containsKey(canonical)) {
        return Left(
          ValidationFailure(
            'Missing required CSV column "$canonical" '
            '(ledger $ledgerDiagnostic).',
            code: 'csv_import_header_missing_$canonical',
          ),
        );
      }
    }

    return Right(
      HeaderIndexLookup(
        accumulator,
      ),
    );
  }

  static String? _resolveHeaderSynonym(String raw) {
    final cleaned = canonicalizeHeader(raw);
    if (cleaned.isEmpty) {
      return null;
    }

    return ImportCsvUseCase._headerSynonyms[cleaned] ??
        ImportCsvUseCase._headerSynonyms[cleaned.toLowerCase()];
  }

  static String canonicalizeHeader(String raw) =>
      raw.replaceAll(RegExp(r'^\uFEFF'), '').trim();

  static String normalizedName(String value) =>
      value.normalizeArabic().trim().toLowerCase();

  static Transaction _buildImportTransaction({
    required String contactId,
    required _CsvValidatedRowData data,
    required DateTime batchNow,
    required bool isArchived,
  }) {
    return Transaction(
      id: UuidUtil.generate(),
      contactId: contactId,
      type: data.type,
      amount: data.amountMinor,
      currency: data.currency,
      description: data.description.isEmpty ? null : data.description,
      itemName: data.itemName.isEmpty ? null : data.itemName,
      transactionDate: data.transactionDate,
      createdAt: batchNow,
      updatedAt: batchNow,
      isArchived: isArchived,
    );
  }

  static String _resolveAvatarColor(String normalizedName) {
    return _defaultAvatarColors[_stableIndex(normalizedName)];
  }

  static int _stableIndex(String value) {
    var sum = 0;
    for (final codeUnit in value.codeUnits) {
      sum = (sum + codeUnit) & 0x7fffffff;
    }

    return sum % _defaultAvatarColors.length;
  }
}

final class _PreparedCsvImportContext {
  const _PreparedCsvImportContext({
    required this.ledgerId,
    required this.headerLookup,
    required this.bodyRows,
    required this.seedContacts,
  });

  final String ledgerId;
  final HeaderIndexLookup headerLookup;
  final List<List<String>> bodyRows;
  final List<Contact> seedContacts;
}

final class _CsvValidatedRowData {
  const _CsvValidatedRowData({
    required this.nameCell,
    required this.phoneSanitized,
    required this.amountMinor,
    required this.currency,
    required this.type,
    required this.transactionDate,
    required this.description,
    required this.itemName,
  });

  final String nameCell;
  final String phoneSanitized;
  final int amountMinor;
  final String currency;
  final TransactionType type;
  final DateTime transactionDate;
  final String description;
  final String itemName;
}

final class _ValidatedImportRowParse {
  const _ValidatedImportRowParse._({
    this.errorMessage,
    this.data,
  });

  factory _ValidatedImportRowParse.error(String message) =>
      _ValidatedImportRowParse._(errorMessage: message);

  factory _ValidatedImportRowParse.ok(_CsvValidatedRowData data) =>
      _ValidatedImportRowParse._(data: data);

  final String? errorMessage;
  final _CsvValidatedRowData? data;
}

final class _LedgerContactIndex {
  _LedgerContactIndex(List<Contact> sharedBacking) : _contacts = sharedBacking {
    _replay();
  }

  final List<Contact> _contacts;

  final Map<String, Contact> _bySanitizedPhone = {};

  final Map<String, List<Contact>> _nameBuckets = {};

  void _replay() {
    _bySanitizedPhone.clear();
    _nameBuckets.clear();
    _contacts.forEach(_attachContactMaps);
  }

  void _attachContactMaps(Contact contact) {
    final phone = WhatsAppUtil.sanitizePhone(contact.phone ?? '');
    if (phone.isNotEmpty) {
      _bySanitizedPhone.putIfAbsent(phone, () => contact);
    }
    final key = ImportCsvUseCase.normalizedName(contact.name);
    _nameBuckets.putIfAbsent(key, () => <Contact>[]).add(contact);
  }

  void add(Contact created) {
    _contacts.add(created);
    _attachContactMaps(created);
  }

  _CsvContactDisposition resolveDisposition(
    String nameRaw,
    String phoneSanitized,
  ) {
    if (phoneSanitized.isNotEmpty) {
      final byPhoneMatch = _bySanitizedPhone[phoneSanitized];
      if (byPhoneMatch != null) {
        return _CsvContactMatched(byPhoneMatch);
      }
    }
    final cohortKey = ImportCsvUseCase.normalizedName(nameRaw);
    final cohort = _nameBuckets[cohortKey];
    if (cohort == null || cohort.isEmpty) {
      return const _CsvContactFresh();
    }
    if (cohort.length > 1) {
      return const _CsvContactAmbiguous();
    }
    return _CsvContactMatched(cohort.single);
  }
}

sealed class _CsvContactDisposition {
  const _CsvContactDisposition();
}

final class _CsvContactMatched extends _CsvContactDisposition {
  _CsvContactMatched(this.contact);

  final Contact contact;
}

final class _CsvContactAmbiguous extends _CsvContactDisposition {
  const _CsvContactAmbiguous();
}

final class _CsvContactFresh extends _CsvContactDisposition {
  const _CsvContactFresh();
}

final class HeaderIndexLookup {
  const HeaderIndexLookup(this._backing);

  final Map<String, int> _backing;

  Map<String, int> get headerBacking => Map<String, int>.unmodifiable(_backing);

  static String pickCsvField(
    List<String> row,
    Map<String, int> headerBacking,
    String column,
  ) {
    final slot = headerBacking[column];
    if (slot == null || slot >= row.length) {
      return '';
    }
    return row[slot];
  }

  String Function(String column) pick(List<String> row) {
    return (String column) => pickCsvField(row, _backing, column);
  }
}

final class _CsvBuildResult {
  const _CsvBuildResult({
    required this.batchContacts,
    required this.batchTransactions,
    required this.batchAuditLogs,
    required this.rowErrors,
    required this.successCount,
    required this.skippedDuplicates,
  });

  final List<Contact> batchContacts;
  final List<Transaction> batchTransactions;
  final List<AuditLog> batchAuditLogs;
  final List<String> rowErrors;
  final int successCount;
  final int skippedDuplicates;
}

CsvPreFlightSummary _analyzeImportSync({
  required List<List<String>> bodyRows,
  required Map<String, int> headerBacking,
  required List<Contact> seedContacts,
}) {
  final index = _LedgerContactIndex(List<Contact>.from(seedContacts));
  final distinctDupIds = <String>{};
  final newIdentityKeys = <String>{};
  var validRows = 0;

  for (final entry in bodyRows.indexed) {
    final rowCells = entry.$2;
    final spreadsheetRowNumber = entry.$1 + 2;
    final parsed = ImportCsvUseCase._parseValidatedImportRow(
      rowCells: rowCells,
      headerBacking: headerBacking,
      spreadsheetRowNumber: spreadsheetRowNumber,
    );
    if (parsed == null) {
      continue;
    }
    if (parsed.errorMessage != null) {
      continue;
    }
    final data = parsed.data!;
    final disposition = index.resolveDisposition(
      data.nameCell,
      data.phoneSanitized,
    );
    switch (disposition) {
      case _CsvContactAmbiguous():
        continue;
      case _CsvContactFresh():
        validRows++;
        newIdentityKeys.add(
          ImportCsvUseCase._newContactIdentityKey(
            data.nameCell,
            data.phoneSanitized,
          ),
        );
      case _CsvContactMatched(:final contact):
        validRows++;
        distinctDupIds.add(contact.id);
    }
  }

  return CsvPreFlightSummary(
    newContactsCount: newIdentityKeys.length,
    duplicateContactsCount: distinctDupIds.length,
    validRowsCount: validRows,
  );
}

_CsvBuildResult _buildEntitiesSync({
  required List<List<String>> bodyRows,
  required Map<String, int> headerBacking,
  required List<Contact> seedContacts,
  required String ledgerId,
  required DuplicateResolutionStrategy duplicateStrategy,
  required int activeContactCount,
  required int activeTransactionCount,
  required Entitlement entitlement,
  required DateTime batchNow,
}) {
  var plannedActiveContacts = activeContactCount;
  var plannedActiveTransactions = activeTransactionCount;
  final index = _LedgerContactIndex(List<Contact>.from(seedContacts));
  final rowErrors = <String>[];
  final batchContacts = <Contact>[];
  final batchTransactions = <Transaction>[];
  final batchAuditLogs = <AuditLog>[];
  var successCount = 0;
  var skippedDuplicates = 0;

  for (final entry in bodyRows.indexed) {
    final rowOffset = entry.$1;
    final rowCells = entry.$2;
    final spreadsheetRowNumber = rowOffset + 2;
    final parsed = ImportCsvUseCase._parseValidatedImportRow(
      rowCells: rowCells,
      headerBacking: headerBacking,
      spreadsheetRowNumber: spreadsheetRowNumber,
    );
    if (parsed == null) {
      continue;
    }
    if (parsed.errorMessage != null) {
      rowErrors.add(parsed.errorMessage!);
      continue;
    }
    final data = parsed.data!;

    final disposition = index.resolveDisposition(
      data.nameCell,
      data.phoneSanitized,
    );

    switch (disposition) {
      case _CsvContactAmbiguous():
        rowErrors.add(
          'Row $spreadsheetRowNumber: Multiple contacts share '
          '`${data.nameCell}` — specify a Phone to disambiguate.',
        );
        continue;
      case _CsvContactFresh():
        final trimmedName = data.nameCell.trim();
        final normalizedName = trimmedName.normalizeArabic();
        final contactArchived =
            !entitlement.canAddContact(plannedActiveContacts);
        if (!contactArchived) {
          plannedActiveContacts++;
        }

        final createdContact = Contact(
          id: UuidUtil.generate(),
          ledgerId: ledgerId,
          name: trimmedName,
          phone: data.phoneSanitized.isEmpty ? null : data.phoneSanitized,
          avatarColor: ImportCsvUseCase._resolveAvatarColor(normalizedName),
          createdAt: batchNow,
          updatedAt: batchNow,
          isArchived: contactArchived,
        );
        batchContacts.add(createdContact);
        batchAuditLogs.add(
          AuditLog(
            id: UuidUtil.generate(),
            entityType: 'contact',
            entityId: createdContact.id,
            action: 'CREATE',
            timestamp: batchNow,
            deviceId: '',
          ),
        );
        index.add(createdContact);

        final transactionArchived = createdContact.isArchived ||
            !entitlement.canAddTransaction(plannedActiveTransactions);
        if (!transactionArchived) {
          plannedActiveTransactions++;
        }

        final transaction = ImportCsvUseCase._buildImportTransaction(
          contactId: createdContact.id,
          data: data,
          batchNow: batchNow,
          isArchived: transactionArchived,
        );
        batchTransactions.add(transaction);
        batchAuditLogs.add(
          AuditLog(
            id: UuidUtil.generate(),
            entityType: 'transaction',
            entityId: transaction.id,
            action: 'CREATE',
            timestamp: batchNow,
            deviceId: '',
          ),
        );
        successCount++;
      case _CsvContactMatched(:final contact):
        if (duplicateStrategy == DuplicateResolutionStrategy.skip) {
          skippedDuplicates++;
          continue;
        }

        final transactionArchived = contact.isArchived ||
            !entitlement.canAddTransaction(plannedActiveTransactions);
        if (!transactionArchived) {
          plannedActiveTransactions++;
        }

        final transaction = ImportCsvUseCase._buildImportTransaction(
          contactId: contact.id,
          data: data,
          batchNow: batchNow,
          isArchived: transactionArchived,
        );
        batchTransactions.add(transaction);
        batchAuditLogs.add(
          AuditLog(
            id: UuidUtil.generate(),
            entityType: 'transaction',
            entityId: transaction.id,
            action: 'CREATE',
            timestamp: batchNow,
            deviceId: '',
          ),
        );
        successCount++;
    }
  }

  return _CsvBuildResult(
    batchContacts: batchContacts,
    batchTransactions: batchTransactions,
    batchAuditLogs: batchAuditLogs,
    rowErrors: rowErrors,
    successCount: successCount,
    skippedDuplicates: skippedDuplicates,
  );
}
