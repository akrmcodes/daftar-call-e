import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_mutation_trigger.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ledger_providers.g.dart';

/// Streams the current active ledgers.
@riverpod
Stream<List<Ledger>> ledgers(Ref ref) {
  return ref.watch(getLedgersUseCaseProvider).execute();
}

/// Tracks the currently selected ledger identifier.
@Riverpod(keepAlive: true)
class SelectedLedgerId extends _$SelectedLedgerId {
  @override
  String? build() => null;

  /// Updates the selected ledger identifier.
  String? get ledgerId => state;

  /// Updates the selected ledger identifier.
  set ledgerId(String? ledgerId) {
    state = ledgerId;
  }

  /// Clears the selected ledger identifier.
  void clear() {
    state = null;
  }
}

/// Mutation controller for ledger operations.
@Riverpod(keepAlive: true)
class LedgerController extends _$LedgerController {
  @override
  void build() {}

  /// Creates a new ledger.
  Future<Either<Failure, Ledger>> createLedger({
    required String name,
    required LedgerType type,
    required String icon,
    required int color,
  }) async {
    final result = await ref
        .read(createLedgerUseCaseProvider)
        .execute(
          name: name,
          type: type,
          icon: icon,
          color: color,
        );
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }

  /// Updates an existing ledger.
  Future<Either<Failure, Ledger>> updateLedger(Ledger ledger) async {
    final result = await ref.read(updateLedgerUseCaseProvider).execute(ledger);
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }

  /// Soft-deletes a ledger.
  Future<Either<Failure, Ledger>> deleteLedger(String ledgerId) async {
    final result =
        await ref.read(deleteLedgerUseCaseProvider).execute(ledgerId);
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }

  /// Restores a soft-deleted ledger.
  Future<Either<Failure, Ledger>> restoreLedger(String ledgerId) async {
    final result =
        await ref.read(restoreLedgerUseCaseProvider).execute(ledgerId);
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }
}
