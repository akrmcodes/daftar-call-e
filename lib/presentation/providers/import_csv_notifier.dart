import 'dart:io';

import 'package:daftar/application/import/import_csv_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/csv_parser.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/duplicate_resolution_strategy.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'import_csv_notifier.g.dart';

enum ImportCsvPhase {
  idle,
  preview,
  importing,
  summary,
}

/// Recoverable issues surfaced before preview succeeds (localized on screen).
enum ImportCsvIdleIssueKind {
  readFailed,
  emptyBytes,
  parseWorkerFailed,
  structureFatal,
}

@immutable
class ImportCsvUiState {
  const ImportCsvUiState({
    this.phase = ImportCsvPhase.idle,
    this.previewRefreshing = false,
    this.importPipelineCommitStarted = false,
    this.fileName,
    this.fileBytes,
    this.headers = const [],
    this.previewRows = const [],
    this.encoding = CsvDecodingMode.auto,
    this.columnMapping = const {},
    this.cachedStructuralParse,
    this.summaryResult,
    this.summaryBlockingMessage,
    this.idleIssueKind,
    this.idleIssueDetail,
    this.targetLedgerId,
  });

  final ImportCsvPhase phase;
  final bool previewRefreshing;

  /// After pre-flight analysis succeeds, `false` means we are resolving duplicates /
  /// still waiting before DB writes (`false` implies pre-flight UX copy).
  final bool importPipelineCommitStarted;
  final String? fileName;
  final Uint8List? fileBytes;
  final List<String> headers;
  final List<List<String>> previewRows;
  final CsvDecodingMode encoding;
  final Map<String, int> columnMapping;
  final CsvStructuralParseOutput? cachedStructuralParse;
  final CsvImportResult? summaryResult;
  final String? summaryBlockingMessage;
  final ImportCsvIdleIssueKind? idleIssueKind;
  final String? idleIssueDetail;

  /// Ledger that will receive imported contacts and transactions.
  final String? targetLedgerId;

  ImportCsvUiState copyWith({
    ImportCsvPhase? phase,
    bool? previewRefreshing,
    bool? importPipelineCommitStarted,
    String? fileName,
    Uint8List? fileBytes,
    List<String>? headers,
    List<List<String>>? previewRows,
    CsvDecodingMode? encoding,
    Map<String, int>? columnMapping,
    CsvStructuralParseOutput? cachedStructuralParse,
    CsvImportResult? summaryResult,
    String? summaryBlockingMessage,
    ImportCsvIdleIssueKind? idleIssueKind,
    String? idleIssueDetail,
    String? targetLedgerId,
    bool clearTargetLedgerId = false,
    bool clearIdleIssue = false,
  }) {
    return ImportCsvUiState(
      phase: phase ?? this.phase,
      previewRefreshing: previewRefreshing ?? this.previewRefreshing,
      importPipelineCommitStarted:
          importPipelineCommitStarted ?? this.importPipelineCommitStarted,
      fileName: fileName ?? this.fileName,
      fileBytes: fileBytes ?? this.fileBytes,
      headers: headers ?? this.headers,
      previewRows: previewRows ?? this.previewRows,
      encoding: encoding ?? this.encoding,
      columnMapping: columnMapping ?? this.columnMapping,
      cachedStructuralParse:
          cachedStructuralParse ?? this.cachedStructuralParse,
      summaryResult: summaryResult ?? this.summaryResult,
      summaryBlockingMessage:
          summaryBlockingMessage ?? this.summaryBlockingMessage,
      idleIssueKind:
          clearIdleIssue ? null : (idleIssueKind ?? this.idleIssueKind),
      idleIssueDetail:
          clearIdleIssue ? null : (idleIssueDetail ?? this.idleIssueDetail),
      targetLedgerId:
          clearTargetLedgerId ? null : (targetLedgerId ?? this.targetLedgerId),
    );
  }
}

Map<String, int> buildInitialColumnMapping({
  required List<String> headers,
  required Map<String, int> suggestion,
}) {
  final count = headers.length;
  int clampIdx(int? idx) {
    if (idx == null || idx < 0 || idx >= count) {
      return -1;
    }
    return idx;
  }

  final out = <String, int>{};
  for (final field in CsvImportColumn.requiredImportFields) {
    out[field] = clampIdx(suggestion[field]);
  }
  for (final field in CsvImportColumn.optionalImportFields) {
    out[field] = clampIdx(suggestion[field]);
  }
  return out;
}

Map<String, int> reconcileColumnMapping({
  required Map<String, int> previous,
  required int headerLen,
  required Map<String, int> suggestion,
}) {
  bool valid(int idx) => idx >= 0 && idx < headerLen;

  final out = <String, int>{};
  for (final field in [
    ...CsvImportColumn.requiredImportFields,
    ...CsvImportColumn.optionalImportFields,
  ]) {
    final prior = previous[field] ?? -1;
    if (valid(prior)) {
      out[field] = prior;
    } else {
      final sug = suggestion[field];
      out[field] = (sug != null && valid(sug)) ? sug : -1;
    }
  }
  return out;
}

bool importCsvMappingComplete(Map<String, int> mapping, int headerLen) {
  if (headerLen <= 0) {
    return false;
  }
  for (final field in CsvImportColumn.requiredImportFields) {
    final idx = mapping[field];
    if (idx == null || idx < 0 || idx >= headerLen) {
      return false;
    }
  }
  return true;
}

Map<String, int> mappingForExecute(Map<String, int> uiMapping) {
  final out = <String, int>{};
  for (final entry in uiMapping.entries) {
    if (entry.value >= 0) {
      out[entry.key] = entry.value;
    }
  }
  return out;
}

@Riverpod(keepAlive: true)
class ImportCsvController extends _$ImportCsvController {
  @override
  ImportCsvUiState build() => const ImportCsvUiState();

  void clearIdleIssue() {
    if (state.idleIssueKind == null && state.idleIssueDetail == null) {
      return;
    }
    state = state.copyWith(clearIdleIssue: true);
  }

  void resetFlow() {
    state = ImportCsvUiState(targetLedgerId: state.targetLedgerId);
  }

  void selectTargetLedger(String ledgerId) {
    final normalized = ledgerId.trim();
    if (normalized.isEmpty) {
      return;
    }
    state = state.copyWith(targetLedgerId: normalized);
  }

  /// Picks a default target ledger when none is set or the current id is stale.
  void syncDefaultTargetLedger({
    required String? prefetchedLedgerId,
    required String? globalSelectedLedgerId,
    required List<Ledger> ledgers,
  }) {
    if (ledgers.isEmpty) {
      if (state.targetLedgerId != null) {
        state = state.copyWith(clearTargetLedgerId: true);
      }
      return;
    }

    final current = state.targetLedgerId;
    if (current != null && ledgers.any((ledger) => ledger.id == current)) {
      return;
    }

    final prefetch = prefetchedLedgerId?.trim();
    if (prefetch != null &&
        prefetch.isNotEmpty &&
        ledgers.any((ledger) => ledger.id == prefetch)) {
      state = state.copyWith(targetLedgerId: prefetch);
      return;
    }

    final global = globalSelectedLedgerId?.trim();
    if (global != null &&
        global.isNotEmpty &&
        ledgers.any((ledger) => ledger.id == global)) {
      state = state.copyWith(targetLedgerId: global);
      return;
    }

    if (ledgers.length == 1) {
      state = state.copyWith(targetLedgerId: ledgers.first.id);
      return;
    }

    state = state.copyWith(clearTargetLedgerId: true);
  }

  void updateColumnMapping(String canonicalField, int columnIndex) {
    if (state.phase != ImportCsvPhase.preview) {
      return;
    }
    state = state.copyWith(
      phase: ImportCsvPhase.preview,
      columnMapping: {
        ...state.columnMapping,
        canonicalField: columnIndex,
      },
    );
  }

  Future<void> pickCsvFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final picked = result.files.single;
    final name = picked.name;

    var bytes = picked.bytes;
    final path = picked.path;
    if (bytes == null &&
        path != null &&
        path.trim().isNotEmpty &&
        !kIsWeb) {
      try {
        bytes = await File(path).readAsBytes();
      } on Object {
        state = state.copyWith(
          encoding: state.encoding,
          idleIssueKind: ImportCsvIdleIssueKind.readFailed,
        );
        return;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      state = state.copyWith(
        encoding: state.encoding,
        idleIssueKind: ImportCsvIdleIssueKind.emptyBytes,
      );
      return;
    }

    await _parseIntoPreview(
      bytes: bytes,
      fileName: name,
      encoding: state.encoding,
      preservePriorMapping: false,
    );
  }

  Future<void> applyEncoding(CsvDecodingMode encoding) async {
    final bytes = state.fileBytes;
    if (bytes == null) {
      state = state.copyWith(encoding: encoding);
      return;
    }

    if (state.phase == ImportCsvPhase.importing ||
        state.phase == ImportCsvPhase.summary) {
      state = state.copyWith(encoding: encoding);
      return;
    }

    await _parseIntoPreview(
      bytes: bytes,
      fileName: state.fileName ?? 'import.csv',
      encoding: encoding,
      preservePriorMapping: state.phase == ImportCsvPhase.preview,
    );
  }

  void beginImportPipeline() {
    state = state.copyWith(phase: ImportCsvPhase.importing);
  }

  void restorePreviewAfterCanceledImportPipeline() {
    state = state.copyWith(phase: ImportCsvPhase.preview);
  }

  void reportImportFatal(String message) {
    state = state.copyWith(
      phase: ImportCsvPhase.summary,
      summaryBlockingMessage: message,
    );
  }

  Future<Either<Failure, CsvPreFlightSummary>> runPreflightAnalyze({
    required String ledgerId,
  }) async {
    final normalized = ledgerId.trim();
    final bytes = state.fileBytes;
    final mappingPayload = mappingForExecute(state.columnMapping);

    if (bytes == null ||
        !importCsvMappingComplete(state.columnMapping, state.headers.length)) {
      return const Left(
        ValidationFailure(
          'Could not analyze import — incomplete column mapping.',
          code: 'csv_import_preflight_mapping_incomplete',
        ),
      );
    }

    return ref.read(importCsvUseCaseProvider).analyzeImport(
          ledgerId: normalized,
          csvBytes: bytes,
          columnIndicesByCanonicalField: mappingPayload,
          decodingMode: state.encoding,
          preParsedStructural: state.cachedStructuralParse,
        );
  }

  Future<void> finalizeImportWithStrategy({
    required String ledgerId,
    required DuplicateResolutionStrategy duplicateStrategy,
  }) async {
    final normalized = ledgerId.trim();
    final bytes = state.fileBytes;
    final mappingPayload = mappingForExecute(state.columnMapping);

    if (normalized.isEmpty ||
        bytes == null ||
        !importCsvMappingComplete(state.columnMapping, state.headers.length)) {
      return;
    }

    state = state.copyWith(
      phase: ImportCsvPhase.importing,
      importPipelineCommitStarted: true,
    );

    final outcome = await ref.read(importCsvUseCaseProvider).execute(
          ledgerId: normalized,
          duplicateStrategy: duplicateStrategy,
          csvBytes: bytes,
          columnIndicesByCanonicalField: mappingPayload,
          decodingMode: state.encoding,
          preParsedStructural: state.cachedStructuralParse,
        );

    outcome.fold(
      (failure) {
        state = state.copyWith(
          phase: ImportCsvPhase.summary,
          summaryBlockingMessage: failure.message,
        );
      },
      (result) {
        state = state.copyWith(
          phase: ImportCsvPhase.summary,
          summaryResult: result,
        );
      },
    );
  }

  Future<void> _parseIntoPreview({
    required Uint8List bytes,
    required String fileName,
    required CsvDecodingMode encoding,
    required bool preservePriorMapping,
  }) async {
    final priorMapping = Map<String, int>.from(state.columnMapping);

    state = state.copyWith(
      phase: ImportCsvPhase.preview,
      previewRefreshing: true,
      fileName: fileName,
      fileBytes: bytes,
      encoding: encoding,
    );

    try {
      final structural = await CsvParserUtil.parseCsvBytesStructured(
        bytes,
        decodingMode: encoding,
      );

      if (structural.isFatal) {
        state = state.copyWith(
          fileName: fileName,
          fileBytes: bytes,
          encoding: encoding,
          idleIssueKind: ImportCsvIdleIssueKind.structureFatal,
          idleIssueDetail: structural.fatalMessage,
        );
        return;
      }

      final suggestion =
          ImportCsvUseCase.suggestColumnIndices(structural.headers);

      final mapping = preservePriorMapping
          ? reconcileColumnMapping(
              previous: priorMapping,
              headerLen: structural.headers.length,
              suggestion: suggestion,
            )
          : buildInitialColumnMapping(
              headers: structural.headers,
              suggestion: suggestion,
            );

      state = state.copyWith(
        phase: ImportCsvPhase.preview,
        previewRefreshing: false,
        fileName: fileName,
        fileBytes: bytes,
        encoding: encoding,
        headers: structural.headers,
        previewRows: structural.bodyRows.take(5).toList(growable: false),
        cachedStructuralParse: structural,
        columnMapping: mapping,
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        fileName: fileName,
        fileBytes: bytes,
        encoding: encoding,
        idleIssueKind: ImportCsvIdleIssueKind.structureFatal,
        idleIssueDetail: error.message,
      );
    } on Object {
      state = state.copyWith(
        fileName: fileName,
        fileBytes: bytes,
        encoding: encoding,
        idleIssueKind: ImportCsvIdleIssueKind.parseWorkerFailed,
      );
    }
  }
}
