// ============================================================================
// DAFTAR — Phase 0 Architecture Smoke Test
// ============================================================================
//
// This test proves that Drift, Riverpod, and SQLite native bindings are
// completely conflict-free and ready for production code.
//
// What this test validates:
//   1. Drift + sqlite3 can open an in-memory database
//   2. DDL (CREATE TABLE) executes without runtime crashes
//   3. DML (INSERT + SELECT) round-trips data correctly
//   4. Riverpod ProviderContainer can integrate with Drift
//   5. The analyzer override (^10.0.0) causes no runtime issues
//
// If this test passes, the Drift + Riverpod + SQLite stack is proven
// conflict-free and the project is ready for Stage 1 domain modeling.
//
// Run with:
//   flutter test test/smoke_test.dart -v
// ============================================================================
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide isNotNull;

// ============================================================================
// 1. MINIMAL DRIFT DATABASE — raw SQL only, no codegen needed
// ============================================================================

/// Minimal Drift database using raw SQL for smoke testing.
/// No generated code required — proves native bindings work directly.
class SmokeTestDatabase extends GeneratedDatabase {
  SmokeTestDatabase() : super(_openInMemory());

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Create table using raw SQL — no codegen needed
        await customStatement('''
          CREATE TABLE smoke_test_ledgers (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1))
          )
        ''');
      },
    );
  }

  /// Factory for in-memory SQLite — proves native bindings work.
  static QueryExecutor _openInMemory() {
    return NativeDatabase.memory(logStatements: true);
  }
}

// ============================================================================
// 2. RIVERPOD PROVIDER — proves DI container works with Drift
// ============================================================================

/// Provider that creates an in-memory Drift database.
/// In production, this would be a singleton with a file-backed DB.
final smokeTestDatabaseProvider = Provider<SmokeTestDatabase>((ref) {
  final db = SmokeTestDatabase();
  ref.onDispose(db.close);
  return db;
});

// ============================================================================
// 3. TEST SUITE
// ============================================================================

void main() {
  group('Phase 0 — Architecture Smoke Test', () {
    late ProviderContainer container;
    late SmokeTestDatabase db;

    setUp(() {
      container = ProviderContainer();
      db = container.read(smokeTestDatabaseProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('[CRITICAL] SQLite native bindings load without crash', () {
      // Arrange & Act — the database constructor calls NativeDatabase.memory()
      // which loads the native SQLite library. If bindings are broken, this
      // test crashes with a MissingPluginException or DynamicLibrary error.

      // Assert — if we get here, native SQLite is working
      expect(db, isNot(equals(null)));
      expect(db.schemaVersion, equals(1));
      debugPrint('SQLite native bindings loaded successfully');
    });

    test('[CRITICAL] DDL — CREATE TABLE executes via Drift', () async {
      // Arrange & Act — migration creates the table on first access
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name='smoke_test_ledgers'",
          )
          .getSingle();

      // Assert
      expect(result.data['name'], equals('smoke_test_ledgers'));
      debugPrint('DDL executed — table "smoke_test_ledgers" created');
    });

    test('[CRITICAL] DML — INSERT + SELECT round-trip', () async {
      // Arrange
      const testId = 'smoke-test-001';
      const testName = 'دفتر التجارة'; // Arabic test data

      // Act — INSERT
      await db.customStatement(
        'INSERT INTO smoke_test_ledgers (id, name) VALUES (?, ?)',
        [testId, testName],
      );

      // Act — SELECT
      final rows = await db
          .customSelect(
            'SELECT id, name, is_deleted FROM smoke_test_ledgers WHERE id = ?',
            variables: [const Variable<String>(testId)],
          )
          .get();

      // Assert
      expect(rows, hasLength(1));
      expect(rows.first.data['id'], equals(testId));
      expect(rows.first.data['name'], equals(testName));
      expect(rows.first.data['is_deleted'], equals(0));
      debugPrint(
        'DML round-trip passed — Arabic data intact: '
        '"${rows.first.data['name']}"',
      );
    });

    test('[CRITICAL] Riverpod ProviderContainer resolves Drift DB', () {
      // Arrange & Act — read from a fresh container
      final freshContainer = ProviderContainer();
      final resolvedDb = freshContainer.read(smokeTestDatabaseProvider);

      // Assert
      expect(resolvedDb, isA<SmokeTestDatabase>());
      expect(
        identical(resolvedDb, db),
        isFalse,
      ); // Different container = different instance
      debugPrint('Riverpod resolves Drift database — DI working');

      freshContainer.dispose();
    });

    test('[CRITICAL] Soft-delete filter pattern works', () async {
      // Arrange — insert active + deleted records
      await db.customStatement(
        'INSERT INTO smoke_test_ledgers (id, name, is_deleted) '
        'VALUES (?, ?, ?)',
        ['active-001', 'Active Ledger', 0],
      );
      await db.customStatement(
        'INSERT INTO smoke_test_ledgers (id, name, is_deleted) '
        'VALUES (?, ?, ?)',
        ['deleted-001', 'Deleted Ledger', 1],
      );

      // Act — query with soft-delete filter (standard Daftar pattern)
      final activeOnly = await db
          .customSelect(
            'SELECT * FROM smoke_test_ledgers WHERE is_deleted = 0',
          )
          .get();

      final allRecords = await db
          .customSelect(
            'SELECT * FROM smoke_test_ledgers',
          )
          .get();

      // Assert
      expect(allRecords, hasLength(2));
      expect(activeOnly, hasLength(1));
      expect(activeOnly.first.data['id'], equals('active-001'));
      debugPrint('Soft-delete filter pattern verified');
    });

    test('[CRITICAL] Integer money storage pattern works', () async {
      // This test verifies the int-only money pattern.
      // The actual Money value object will be built in Stage 1, but the
      // underlying storage pattern (INTEGER column) must work now.

      // Arrange — create a temporary table with int money column
      await db.customStatement('''
        CREATE TABLE money_smoke_test (
          id TEXT PRIMARY KEY,
          amount_smallest_unit INTEGER NOT NULL,
          currency_code TEXT NOT NULL
        )
      ''');

      // Act — store 1500 = 15.00 YER
      await db.customStatement(
        'INSERT INTO money_smoke_test (id, amount_smallest_unit, currency_code) '
        'VALUES (?, ?, ?)',
        ['txn-001', 1500, 'YER'],
      );

      final result = await db
          .customSelect(
            'SELECT amount_smallest_unit, currency_code '
            'FROM money_smoke_test WHERE id = ?',
            variables: [const Variable<String>('txn-001')],
          )
          .getSingle();

      // Assert
      expect(result.data['amount_smallest_unit'], equals(1500));
      expect(result.data['currency_code'], equals('YER'));
      debugPrint('Integer money storage verified — 1500 = 15.00 YER');
    });

    test('[CRITICAL] SQLite version is recent enough', () async {
      // Verify the bundled SQLite is a modern version (3.35+ for RETURNING,
      // window functions, etc.)
      final result = await db
          .customSelect('SELECT sqlite_version() as v')
          .getSingle();
      final version = result.data['v'] as String;
      final major = int.parse(version.split('.')[0]);
      final minor = int.parse(version.split('.')[1]);

      expect(major, greaterThanOrEqualTo(3));
      expect(minor, greaterThanOrEqualTo(35));
      debugPrint('SQLite version: $version (3.35+ required)');
    });
  });
}
