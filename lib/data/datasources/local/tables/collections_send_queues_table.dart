import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:drift/drift.dart';

/// Hybrid E send-queue header (one in-flight Sending i of N at a time).
///
/// Row class is generated as `CollectionsSendQueueHeader` so it does not clash
/// with the domain send-queue snapshot.
@TableIndex(
  name: 'idx_collections_send_queues_status_updated',
  columns: {#status, #updatedAt},
)
class CollectionsSendQueueHeaders extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// `active`, `paused`, or `completed`.
  TextColumn get status => textEnum<CollectionsSendQueueStatus>()();

  /// True after a successful Open until the host returns from background.
  BoolColumn get awaitingResume =>
      boolean().withDefault(const Constant(false))();

  /// Draft locale (`ar` / `en`).
  TextColumn get locale => text()();

  /// Store name baked into drafts.
  TextColumn get storeName => text()();

  /// Merchant calendar day `YYYY-MM-DD`.
  TextColumn get localDay => text()();

  /// Drive backup outcome at close time.
  TextColumn get backupStatus => text()();

  /// Device-generated send-batch UUID (SMTP path). Null on Hybrid E leftover.
  TextColumn get batchId => text().nullable()();

  /// Yes / Top 5 / No.
  TextColumn get reminderPolicy => text()();

  /// None / selective / selected.
  TextColumn get pdfPolicy => text()();

  /// True when backup queued, failed, or unsigned.
  BoolColumn get needsHuman => boolean().withDefault(const Constant(false))();

  /// Original overdue shortlist length (may exceed desk rows on Top 5).
  IntColumn get overdueTotal => integer()();

  /// Integer debt row count for [localDay].
  IntColumn get debtCount => integer()();

  /// Integer payment row count for [localDay].
  IntColumn get paymentCount => integer()();

  /// JSON array of `{currencyCode, debtMinor, paymentMinor}` (ints only).
  TextColumn get totalsJson => text()();

  /// UTC insert time.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// UTC last mutation.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'collections_send_queues';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ranked Hybrid E queue items (device-owned draft snapshot).
///
/// Row class is generated as `CollectionsSendQueueItemRow`.
@TableIndex(
  name: 'idx_collections_send_queue_items_queue_sort',
  columns: {#queueId, #sortOrder},
)
class CollectionsSendQueueItemRows extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Parent queue UUID.
  TextColumn get queueId => text()();

  /// Stable rank (0-based).
  IntColumn get sortOrder => integer()();

  /// Contact UUID.
  TextColumn get contactId => text()();

  /// Display name snapshot.
  TextColumn get name => text()();

  /// Phone snapshot for leftover `wa.me`.
  TextColumn get phone => text()();

  /// Email snapshot for SMTP send-batch.
  TextColumn get email => text().nullable()();

  /// Ledger UUID snapshot.
  TextColumn get ledgerId => text()();

  /// Signed net (`totalPayment - totalDebt`) in integer minor units.
  IntColumn get netBalance => integer()();

  /// ISO currency for [netBalance].
  TextColumn get currencyCode => text()();

  /// Oldest unpaid age in local days.
  IntColumn get ageDays => integer()();

  /// Friendly / reminder / firm.
  TextColumn get toneBand => text()();

  /// Appendix C.2 draft body.
  TextColumn get body => text()();

  /// Appendix C.2 subject snapshot.
  TextColumn get subject => text().withDefault(const Constant(''))();

  /// When true, Open uses the statement share sheet.
  BoolColumn get attachPdf => boolean().withDefault(const Constant(false))();

  /// `pending` | `skipped` | `opened` | `sending` | `sent` | `failed`.
  TextColumn get status => textEnum<CollectionsDeskRowStatus>()();

  /// Gmail `Message-ID` when [status] is sent.
  TextColumn get smtpMessageId => text().nullable()();

  /// SMTP reply code (e.g. `250`, `535`).
  IntColumn get smtpCode => integer().nullable()();

  /// UTC insert time.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// UTC last mutation.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'collections_send_queue_items';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
