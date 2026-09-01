import 'package:daftar/domain/value_objects/contact_statement_export.dart';

/// Application port for statement PDF bytes. Presentation implements this
/// with `PdfGenerator` so the use case never imports Flutter.
abstract class CollectionsStatementPdfRenderer {
  /// Renders [prepared] on an isolate. Throws `TimeoutException` on the 30s cap.
  Future<List<int>> render({
    required ContactStatementExport prepared,
    required bool isRtl,
  });
}
