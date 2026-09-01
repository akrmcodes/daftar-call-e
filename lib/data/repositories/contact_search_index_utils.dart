import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:drift/drift.dart' as drift;

/// Replaces the FTS search row for a contact.
Future<void> upsertContactSearchIndex(
  db.AppDatabase database,
  String contactId,
  String contactName,
) async {
  await removeContactSearchIndex(database, contactId);
  await database.customInsert(
    'INSERT INTO contact_fts (contact_id, normalized_name) VALUES (?, ?)',
    variables: [
      drift.Variable<String>(contactId),
      drift.Variable<String>(contactName.normalizeArabic()),
    ],
  );
}

/// Removes a contact from the FTS search table.
Future<void> removeContactSearchIndex(
  db.AppDatabase database,
  String contactId,
) async {
  await database.customStatement(
    'DELETE FROM contact_fts WHERE contact_id = ?',
    [contactId],
  );
}

Future<void> bulkRemoveContactSearchIndex(
  db.AppDatabase database,
  List<String> contactIds,
) async {
  if (contactIds.isEmpty) {
    return;
  }

  await database.customStatement(
    'DELETE FROM contact_fts WHERE contact_id IN (${List.filled(contactIds.length, '?').join(',')})',
    contactIds,
  );
}

Future<void> bulkUpsertContactSearchIndex(
  db.AppDatabase database,
  Map<String, String> idToName,
) async {
  if (idToName.isEmpty) {
    return;
  }

    await database.batch((batch) {
      for (final entry in idToName.entries) {
        batch.customStatement(
          'INSERT INTO contact_fts (contact_id, normalized_name) VALUES (?, ?)',
          [
            entry.key,
            entry.value.normalizeArabic(),
          ],
        );
      }
    });
}
