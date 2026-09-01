import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists generated PDF statement bytes for sharing.
///
/// Exports are written under the OS temp directory so shared copies are not
/// retained in app documents (the system may reclaim temp storage). Writes
/// are flushed and verified for non-zero length to surface silent filesystem
/// failures (encountered on some Android low-storage scenarios).
abstract final class PdfStorageService {
  /// Saves [pdfBytes] under [getTemporaryDirectory] for the share sheet.
  ///
  /// The filename is `Statement_{sanitizedContact}_{timestamp}.pdf` for a
  /// stable, professional attachment name. Returns the written [File].
  static Future<File> saveStatement({
    required List<int> pdfBytes,
    required String contactName,
  }) async {
    if (pdfBytes.isEmpty) {
      throw const FileSystemException('Refusing to save empty PDF payload');
    }

    final directory = await getTemporaryDirectory();
    final statementsDir = Directory(p.join(directory.path, 'daftar_statements'));

    if (!statementsDir.existsSync()) {
      statementsDir.createSync(recursive: true);
    }

    final sanitizedName = _sanitizeFilename(contactName);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'Statement_${sanitizedName}_$timestamp.pdf';
    final file = File(p.join(statementsDir.path, filename));

    await file.writeAsBytes(pdfBytes, flush: true);

    // Defensive: some Android filesystems report a successful write even
    // when the actual on-disk size is zero (e.g. quota exceeded). Verify
    // that the file we hand to the share sheet is not silently empty.
    final writtenLength = await file.length();
    if (writtenLength == 0) {
      throw const FileSystemException(
        'PDF file was written but on-disk length is zero',
      );
    }

    return file;
  }

  /// Saves [pdfBytes] for a ledger summary export.
  ///
  /// Filename pattern: `LedgerSummary_{sanitizedLedger}_{timestamp}.pdf`.
  static Future<File> saveLedgerSummary({
    required List<int> pdfBytes,
    required String ledgerName,
  }) async {
    if (pdfBytes.isEmpty) {
      throw const FileSystemException('Refusing to save empty PDF payload');
    }

    final directory = await getTemporaryDirectory();
    final summariesDir = Directory(p.join(directory.path, 'daftar_summaries'));

    if (!summariesDir.existsSync()) {
      summariesDir.createSync(recursive: true);
    }

    final sanitizedName = _sanitizeFilename(ledgerName);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'LedgerSummary_${sanitizedName}_$timestamp.pdf';
    final file = File(p.join(summariesDir.path, filename));

    await file.writeAsBytes(pdfBytes, flush: true);

    final writtenLength = await file.length();
    if (writtenLength == 0) {
      throw const FileSystemException(
        'PDF file was written but on-disk length is zero',
      );
    }

    return file;
  }

  /// Strips characters that are unsafe for FAT32 / APFS / ext4 filenames.
  /// Arabic characters are explicitly preserved (the existing regex already
  /// only strips ASCII control + reserved punctuation). When the result is
  /// empty (e.g. caller passed a name composed entirely of stripped chars
  /// or just whitespace), we fall back to a stable placeholder so the
  /// final filename always has a meaningful, non-empty stem.
  static String _sanitizeFilename(String name) {
    final stripped = name
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    if (stripped.isEmpty) {
      return 'contact';
    }
    return stripped;
  }
}
