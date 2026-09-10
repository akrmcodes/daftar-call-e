import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/tables/activation_codes_table.dart';
import 'package:daftar/data/datasources/local/tables/agent_outbox_rows_table.dart';
import 'package:daftar/data/datasources/local/tables/agent_sessions_table.dart';
import 'package:daftar/data/datasources/local/tables/agent_turns_table.dart';
import 'package:daftar/data/datasources/local/tables/app_settings_table.dart';
import 'package:daftar/data/datasources/local/tables/audit_logs_table.dart';
import 'package:daftar/data/datasources/local/tables/backup_metadatas_table.dart';
import 'package:daftar/data/datasources/local/tables/collection_call_batches_table.dart';
import 'package:daftar/data/datasources/local/tables/collection_call_runs_table.dart';
import 'package:daftar/data/datasources/local/tables/collection_promises_table.dart';
import 'package:daftar/data/datasources/local/tables/collections_send_queues_table.dart';
import 'package:daftar/data/datasources/local/tables/contact_balances_table.dart';
import 'package:daftar/data/datasources/local/tables/contacts_table.dart';
import 'package:daftar/data/datasources/local/tables/currencies_table.dart';
import 'package:daftar/data/datasources/local/tables/day_journal_entries_table.dart';
import 'package:daftar/data/datasources/local/tables/drive_backup_queue_rows_table.dart';
import 'package:daftar/data/datasources/local/tables/ledgers_table.dart';
import 'package:daftar/data/datasources/local/tables/merchant_profiles_table.dart';
import 'package:daftar/data/datasources/local/tables/merge_conflicts_table.dart';
import 'package:daftar/data/datasources/local/tables/sync_operations_table.dart';
import 'package:daftar/data/datasources/local/tables/sync_outbound_acks_table.dart';
import 'package:daftar/data/datasources/local/tables/transactions_table.dart';
import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/enums/call_batch_status.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart';

part 'drift_database.g.dart';

/// The main Drift database class for the Daftar application.
///
/// Assembles all table definitions and configures schema migration.
/// On first launch (schema version 1), seeds:
/// - Built-in currencies: YER, SAR, USD
/// - Default single-row AppSettings entry
///
/// ## Usage
/// ```dart
/// final db = AppDatabase(NativeDatabase.createInBackground(
///   File('path/to/daftar.db'),
/// ));
/// ```
@DriftDatabase(
  tables: [
    Ledgers,
    MerchantProfiles,
    Contacts,
    Transactions,
    Currencies,
    ContactBalances,
    AppSettingsTable,
    BackupMetadatas,
    DriveBackupQueueRows,
    ActivationCodes,
    AuditLogs,
    SyncOperations,
    MergeConflicts,
    SyncOutboundAcks,
    DayJournalEntries,
    AgentSessions,
    AgentTurns,
    AgentOutboxRows,
    CollectionsSendQueueHeaders,
    CollectionsSendQueueItemRows,
    CollectionCallBatches,
    CollectionCallRuns,
    CollectionPromises,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the database with the given `QueryExecutor`.
  ///
  /// The executor is typically a `NativeDatabase` instance pointing
  /// to the on-disk `.db` file.
  AppDatabase(super.e);

  @override
  int get schemaVersion => DbConstants.schemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // 1. Create all tables and indexes
      await m.createAll();

      // 2. Create FTS5 virtual table for Arabic contact name search
      await _createContactFtsTable();

      // 3. Seed built-in currencies
      await _seedBuiltInCurrencies();

      // 4. Insert default AppSettings row
      await _seedDefaultSettings();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(backupMetadatas, backupMetadatas.googleDriveFileId);
        await m.addColumn(appSettingsTable, appSettingsTable.googleAccountId);
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.googleAccountEmail,
        );
      }
      // v3: Drive backup upload queue (offline-first resume). Idempotent for
      // installs that already created this table via a prior migration path.
      if (from < 3) {
        await m.createTable(driveBackupQueueRows);
      }
      if (from < 4) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.driveAutoBackupEnabled,
        );
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.driveAutoBackupInterval,
        );
      }
      if (from < 5) {
        await m.addColumn(ledgers, ledgers.isArchived);
        await m.addColumn(contacts, contacts.isArchived);
        await m.addColumn(transactions, transactions.isArchived);
      }
      if (from < 6) {
        await m.addColumn(appSettingsTable, appSettingsTable.isAppLockEnabled);
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.lockTimeoutSeconds,
        );
      }
      // v7: Merchant branding profile (Pro+). Idempotent for fresh installs
      // that already received this table via onCreate → createAll().
      if (from < 7) {
        await m.createTable(merchantProfiles);
      }
      if (from < 8) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.isMultiCurrencyEnabled,
        );
      }
      if (from < 9) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.isSwipeToDeleteEnabled,
        );
      }
      if (from < 10) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.lastAutoBackupOutcome,
        );
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.lastAutoBackupFailureCode,
        );
      }
      if (from < 11) {
        await (update(
          currencies,
        )..where((tbl) => tbl.code.equals(DbConstants.currencyYer))).write(
          const CurrenciesCompanion(decimalPlaces: Value(0)),
        );
      }
      if (from < 12) {
        await m.addColumn(ledgers, ledgers.isUserArchived);
        await m.addColumn(ledgers, ledgers.carryForwardTargetLedgerId);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_user_archived '
          'ON ledgers (is_user_archived)',
        );
      }
      if (from < 13) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_txn_contact_list '
          'ON transactions (contact_id, is_deleted, is_archived, '
          'transaction_date, created_at)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_contacts_ledger_active_name '
          'ON contacts (ledger_id, is_deleted, is_archived, name)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_ledgers_active_list '
          'ON ledgers (is_deleted, is_archived, is_user_archived, '
          'sort_order, name)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_audit_entity_timestamp '
          'ON audit_logs (entity_type, entity_id, timestamp)',
        );
        await customStatement(
          'DROP INDEX IF EXISTS idx_txn_workspace_status',
        );
        await customStatement(
          'DROP INDEX IF EXISTS idx_contacts_workspace_status',
        );
      }
      if (from < 14) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.hasSeenOnboarding,
        );
      }
      // v15: Merge Engine tables (Stage 8.4) — applied sync ops + conflicts.
      if (from < 15) {
        await m.createTable(syncOperations);
        await m.createTable(mergeConflicts);
      }
      // v16: Outbound push acknowledgments (Stage 8.4 Sync Engine).
      if (from < 16) {
        await m.createTable(syncOutboundAcks);
      }
      // v17: Server-rejected push ops are settled locally instead of being
      // retried forever, and the pull cursor comes from the server.
      if (from < 17) {
        await m.addColumn(syncOutboundAcks, syncOutboundAcks.rejectionCode);
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.syncPullWatermarkOpSeq,
        );
      }
      // v18: Replace legacy SAR abbreviation ر.س with official U+20C1.
      if (from < 18) {
        await (update(
          currencies,
        )..where((tbl) => tbl.code.equals(DbConstants.currencySar))).write(
          const CurrenciesCompanion(symbol: Value('\u20C1')),
        );
      }
      // v19: Closing Agent contest tables (day journal, sessions, turns,
      // thin outbox). Idempotent for fresh installs via onCreate → createAll().
      if (from < 19) {
        await m.createTable(dayJournalEntries);
        await m.createTable(agentSessions);
        await m.createTable(agentTurns);
        await m.createTable(agentOutboxRows);
      }
      // v20: FAB first-run tip for Closing Agent.
      if (from < 20) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.hasSeenAgentFabTip,
        );
      }
      // v21: Closing localDay summary query on createdAt (Appendix J.4).
      if (from < 21) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_txn_created_at '
          'ON transactions (created_at)',
        );
      }
      // v22: Hybrid E Collections send queue (process-death Sending i of N).
      if (from < 22) {
        await m.createTable(collectionsSendQueueHeaders);
        await m.createTable(collectionsSendQueueItemRows);
        await _ensureCollectionsSendQueueStatusUpdatedIndex();
      }
      // v23: contacts.email + SMTP send-batch fields on the Collections queue.
      if (from < 23) {
        await m.addColumn(contacts, contacts.email);
        await m.addColumn(
          collectionsSendQueueHeaders,
          collectionsSendQueueHeaders.batchId,
        );
        await m.addColumn(
          collectionsSendQueueItemRows,
          collectionsSendQueueItemRows.email,
        );
        await m.addColumn(
          collectionsSendQueueItemRows,
          collectionsSendQueueItemRows.subject,
        );
        await m.addColumn(
          collectionsSendQueueItemRows,
          collectionsSendQueueItemRows.smtpMessageId,
        );
        await m.addColumn(
          collectionsSendQueueItemRows,
          collectionsSendQueueItemRows.smtpCode,
        );
        await _ensureContactsEmailIndex();
      }
      // v24: mute on-device TTS for confirm read-back and closing report.
      if (from < 24) {
        await m.addColumn(appSettingsTable, appSettingsTable.ttsMuted);
      }
      // v25: contest Architecture HUD toggle (default off; seeder turns on).
      if (from < 25) {
        await m.addColumn(
          appSettingsTable,
          appSettingsTable.demoArchitectureHud,
        );
      }
      // v26: Confirm & Call collection tables + per-contact DNC.
      if (from < 26) {
        await m.createTable(collectionCallBatches);
        await m.createTable(collectionCallRuns);
        await m.createTable(collectionPromises);
        await m.addColumn(contacts, contacts.doNotCall);
      }
      // v27: per-run retry count for one no-answer/voicemail HITL retry.
      if (from < 27) {
        await m.addColumn(collectionCallRuns, collectionCallRuns.retryCount);
      }
      // v28: merchant CALL-E outbound kill switch in app settings.
      if (from < 28) {
        await m.addColumn(appSettingsTable, appSettingsTable.calleAllowDial);
      }
    },
    beforeOpen: (details) async {
      // Idempotent for installs already on v22 before the composite index.
      await _ensureCollectionsSendQueueStatusUpdatedIndex();
      await _ensureContactsEmailIndex();
    },
  );

  Future<void> _ensureCollectionsSendQueueStatusUpdatedIndex() {
    return customStatement(
      'CREATE INDEX IF NOT EXISTS '
      'idx_collections_send_queues_status_updated '
      'ON collections_send_queues (status, updated_at)',
    );
  }

  Future<void> _ensureContactsEmailIndex() {
    return customStatement(
      'CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts (email)',
    );
  }

  /// Creates the FTS5 virtual table for Arabic-normalized contact search.
  ///
  /// FTS5 virtual tables are not supported by Drift's code generator,
  /// so we create them via raw SQL in the migration.
  ///
  /// The table stores:
  /// - `contact_id`: Join key to the contacts table (UNINDEXED).
  /// - `normalized_name`: Arabic-normalized name for search matching.
  ///
  /// Uses the `unicode61` tokenizer for broad Unicode support.
  Future<void> _createContactFtsTable() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS contact_fts USING fts5(
        contact_id UNINDEXED,
        normalized_name,
        tokenize='unicode61'
      )
    ''');
  }

  /// Seeds the three built-in currencies: YER, SAR, USD.
  ///
  /// These are required for the app to function and cannot be deleted
  /// by the user (isBuiltIn = true).
  Future<void> _seedBuiltInCurrencies() async {
    // Algorithm: Insert each built-in currency with a unique UUID.
    // These currencies are marked as isBuiltIn = true so the UI
    // prevents deletion.

    await batch((b) {
      b.insertAll(currencies, [
        // 1. Yemeni Rial — primary target market currency
        CurrenciesCompanion.insert(
          id: UuidUtil.generate(),
          code: DbConstants.currencyYer,
          symbol: '﷼',
          nameAr: 'ريال يمني',
          nameEn: 'Yemeni Rial',
          decimalPlaces: 0,
          isBuiltIn: const Value(true),
          isActive: const Value(true),
        ),
        // 2. Saudi Riyal — official SAMA symbol (Unicode U+20C1)
        CurrenciesCompanion.insert(
          id: UuidUtil.generate(),
          code: DbConstants.currencySar,
          symbol: '\u20C1',
          nameAr: 'ريال سعودي',
          nameEn: 'Saudi Riyal',
          decimalPlaces: 2,
          isBuiltIn: const Value(true),
          isActive: const Value(true),
        ),
        // 3. US Dollar — common reference currency
        CurrenciesCompanion.insert(
          id: UuidUtil.generate(),
          code: DbConstants.currencyUsd,
          symbol: r'$',
          nameAr: 'دولار أمريكي',
          nameEn: 'US Dollar',
          decimalPlaces: 2,
          isBuiltIn: const Value(true),
          isActive: const Value(true),
        ),
      ]);
    });
  }

  /// Inserts the default single-row AppSettings entry.
  ///
  /// Uses defaults defined in DbConstants and the table definition.
  Future<void> _seedDefaultSettings() async {
    await into(appSettingsTable).insert(
      AppSettingsTableCompanion.insert(),
    );
  }
}
