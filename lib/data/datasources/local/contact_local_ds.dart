import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/contact_mapper.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/contact_search_row.dart';
import 'package:daftar/data/models/contact_summary_row.dart';
import 'package:daftar/data/models/reminder_eligible_contact_row.dart';
import 'package:daftar/data/models/voice_entity_resolution_row.dart';
import 'package:daftar/data/repositories/contact_search_index_utils.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for contact persistence and FTS search.
class ContactLocalDataSource {
  /// Creates a contact local data source.
  ContactLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Creates a contact row and syncs the FTS index.
  Future<ContactModel> createContact(ContactModel contact) async {
    await database.transaction(() async {
      await database.into(database.contacts).insert(contact.toDrift());
      await upsertContactSearchIndex(database, contact.id, contact.name);
    });

    return contact;
  }

  /// Updates an existing contact row and refreshes the FTS index.
  Future<ContactModel> updateContact(ContactModel contact) async {
    final updatedRows = await database.transaction(() async {
      final count =
          await (database.update(database.contacts)
                ..where((table) => table.id.equals(contact.id)))
              .write(contact.toCompanion());

      if (count > 0) {
        await upsertContactSearchIndex(database, contact.id, contact.name);
      }

      return count;
    });

    if (updatedRows == 0) {
      throw StateError('Contact not found: ${contact.id}');
    }

    return contact;
  }

  /// Soft-deletes a contact row and removes it from the FTS index.
  Future<ContactModel> deleteContact(String contactId) async {
    final existing = await getContactById(contactId);
    if (existing == null) {
      throw StateError('Contact not found: $contactId');
    }

    final deleted = ContactModel(
      id: existing.id,
      ledgerId: existing.ledgerId,
      name: existing.name,
      phone: existing.phone,
      email: existing.email,
      notes: existing.notes,
      creditLimit: existing.creditLimit,
      creditCurrency: existing.creditCurrency,
      avatarColor: existing.avatarColor,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
      isDeleted: true,
      syncVersion: existing.syncVersion + 1,
    );

    await database.transaction(() async {
      await (database.update(
        database.contacts,
      )..where((table) => table.id.equals(contactId))).write(
        db.ContactsCompanion(
          isDeleted: const drift.Value(true),
          updatedAt: drift.Value(deleted.updatedAt),
          syncVersion: drift.Value(deleted.syncVersion),
        ),
      );
      await removeContactSearchIndex(database, contactId);
    });

    return deleted;
  }

  Future<int> bulkSoftDeleteContactsByLedgerId(
    String ledgerId, {
    required DateTime updatedAt,
  }) async {
    return (database.update(database.contacts)
          ..where((table) => table.ledgerId.equals(ledgerId))
          ..where((table) => table.isDeleted.equals(false)))
        .write(
      db.ContactsCompanion.custom(
        isDeleted: const drift.Constant(true),
        updatedAt: drift.Variable(updatedAt),
        syncVersion: database.contacts.syncVersion + const drift.Constant(1),
      ),
    );
  }

  Future<int> bulkRestoreContactsByLedgerId({
    required String ledgerId,
    required DateTime deletedAt,
    required DateTime restoredAt,
  }) async {
    return (database.update(database.contacts)
          ..where((table) => table.ledgerId.equals(ledgerId))
          ..where((table) => table.isDeleted.equals(true))
          ..where((table) => table.updatedAt.equals(deletedAt)))
        .write(
      db.ContactsCompanion.custom(
        isDeleted: const drift.Constant(false),
        updatedAt: drift.Variable(restoredAt),
        syncVersion: database.contacts.syncVersion + const drift.Constant(1),
      ),
    );
  }

  Future<void> bulkCreateContacts(List<ContactModel> contacts) async {
    if (contacts.isEmpty) {
      return;
    }

    await database.batch((batch) {
      batch.insertAll(
        database.contacts,
        contacts.map((contact) => contact.toDrift()).toList(growable: false),
      );
    });
  }

  /// Watches active contacts for a ledger, sorted by name.
  Stream<List<ContactModel>> watchContactsByLedger(String ledgerId) {
    return (database.select(database.contacts)
          ..where((table) => table.ledgerId.equals(ledgerId))
          ..where(
            (table) =>
                table.isDeleted.equals(false) & table.isArchived.equals(false),
          )
          ..orderBy([
            (table) => drift.OrderingTerm(expression: table.name),
          ]))
        .watch()
        .map(
          (rows) => rows.map((row) => row.toModel()).toList(growable: false),
        );
  }

  Stream<int> watchContactCountByLedger(String ledgerId) {
    return database
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM contacts '
          'WHERE ledger_id = ? AND is_deleted = 0 AND is_archived = 0',
          variables: [drift.Variable.withString(ledgerId)],
          readsFrom: {database.contacts},
        )
        .watchSingle()
        .map((row) => row.read<int>('cnt'));
  }

  Stream<List<ContactSummaryRow>> watchContactSummariesByLedger(
    String ledgerId,
  ) {
    return database
        .customSelect(
          '''
SELECT
  c.id AS contact_id,
  c.name,
  c.phone,
  c.avatar_color,
  c.credit_limit,
  c.credit_currency,
  cb.currency_code,
  cb.total_debt,
  cb.total_payment,
  cb.net_balance,
  (SELECT COUNT(*) FROM transactions t
   WHERE t.contact_id = c.id AND t.is_deleted = 0 AND t.is_archived = 0) AS txn_count
FROM contacts c
LEFT JOIN contact_balances cb ON c.id = cb.contact_id
WHERE c.ledger_id = ? AND c.is_deleted = 0 AND c.is_archived = 0
ORDER BY c.name COLLATE NOCASE
''',
          variables: [drift.Variable.withString(ledgerId)],
          readsFrom: {
            database.contacts,
            database.contactBalances,
            database.transactions,
          },
        )
        .watch()
        .map(
          (rows) => rows
              .map(ContactSummaryRow.fromQueryRow)
              .toList(growable: false),
        );
  }

  /// Returns a contact by ID.
  Future<ContactModel?> getContactById(String contactId) async {
    final row = await (database.select(
      database.contacts,
    )..where((table) => table.id.equals(contactId))).getSingleOrNull();
    return row?.toModel();
  }

  /// Searches contacts using the raw FTS5 table.
  Future<List<ContactSearchRow>> searchContacts(
    String query, {
    bool excludeUserArchivedLedgers = false,
  }) async {
    final normalizedQuery = _buildFtsQuery(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final ledgerScopeClause = excludeUserArchivedLedgers
        ? '''
        AND l.is_user_archived = 0
        AND l.is_archived = 0
      '''
        : '';

    final rows = await database
        .customSelect(
          '''
      SELECT
        c.id AS id,
        c.ledger_id AS ledgerId,
        c.name AS name,
        c.phone AS phone,
        c.email AS email,
        c.notes AS notes,
        c.credit_limit AS creditLimit,
        c.credit_currency AS creditCurrency,
        c.avatar_color AS avatarColor,
        c.created_at AS createdAt,
        c.updated_at AS updatedAt,
        c.is_deleted AS isDeleted,
        c.is_archived AS isArchived,
        c.do_not_call AS doNotCall,
        c.sync_version AS syncVersion,
        l.name AS ledgerName,
        l.is_user_archived AS isLedgerUserArchived
      FROM contact_fts
      JOIN contacts c ON c.id = contact_fts.contact_id
      JOIN ledgers l ON l.id = c.ledger_id
      WHERE contact_fts MATCH ?
        AND c.is_deleted = 0
        AND c.is_archived = 0
        AND l.is_deleted = 0
        $ledgerScopeClause
      ORDER BY c.name COLLATE NOCASE
      LIMIT 50
      ''',
          variables: [drift.Variable<String>(normalizedQuery)],
        )
        .get();

    return rows
        .map(
          (row) => ContactSearchRow(
            contact: db.Contact(
              id: row.read<String>('id'),
              ledgerId: row.read<String>('ledgerId'),
              name: row.read<String>('name'),
              phone: row.read<String?>('phone'),
              email: row.read<String?>('email'),
              notes: row.read<String?>('notes'),
              creditLimit: row.read<int?>('creditLimit'),
              creditCurrency: row.read<String?>('creditCurrency'),
              avatarColor: row.read<String>('avatarColor'),
              createdAt: row.read<DateTime>('createdAt'),
              updatedAt: row.read<DateTime>('updatedAt'),
              isDeleted: row.read<bool>('isDeleted'),
              isArchived: row.read<bool>('isArchived'),
              doNotCall: row.read<bool>('doNotCall'),
              syncVersion: row.read<int>('syncVersion'),
            ).toModel(),
            ledgerName: row.read<String>('ledgerName'),
            isLedgerUserArchived: row.read<bool>('isLedgerUserArchived'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<VoiceEntityResolutionRow>> getVoiceEntityResolutionContext() async {
    final rows = await database
        .customSelect(
          '''
      SELECT
        c.id AS contactId,
        c.name AS contactName,
        c.ledger_id AS ledgerId
      FROM contacts c
      INNER JOIN ledgers l ON l.id = c.ledger_id
      WHERE c.is_deleted = 0
        AND c.is_archived = 0
        AND l.is_deleted = 0
        AND l.is_archived = 0
        AND l.is_user_archived = 0
      ORDER BY c.name COLLATE NOCASE
      ''',
        )
        .get();

    return rows
        .map(
          (row) => VoiceEntityResolutionRow(
            contactId: row.read<String>('contactId'),
            contactName: row.read<String>('contactName'),
            ledgerId: row.read<String>('ledgerId'),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ReminderEligibleContactRow>>
  getContactsEligibleForAutomatedReminders() async {
    final rows = await database
        .customSelect(
          '''
      SELECT
        c.id AS contactId,
        c.name AS contactName,
        c.ledger_id AS ledgerId,
        c.phone AS phone,
        c.email AS email
      FROM contacts c
      INNER JOIN ledgers l ON l.id = c.ledger_id
      WHERE c.is_deleted = 0
        AND c.is_archived = 0
        AND l.is_deleted = 0
        AND l.is_archived = 0
        AND l.is_user_archived = 0
        AND c.email IS NOT NULL
        AND TRIM(c.email) != ''
      ORDER BY c.name COLLATE NOCASE
      ''',
        )
        .get();

    return rows
        .map(
          (row) => ReminderEligibleContactRow(
            contactId: row.read<String>('contactId'),
            contactName: row.read<String>('contactName'),
            ledgerId: row.read<String>('ledgerId'),
            phone: row.read<String?>('phone'),
            email: row.read<String?>('email'),
          ),
        )
        .toList(growable: false);
  }

  String _buildFtsQuery(String query) {
    final normalized = query.normalizeArabic();
    if (normalized.isEmpty) {
      return '';
    }

    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => '$token*')
        .join(' ');
  }
}
