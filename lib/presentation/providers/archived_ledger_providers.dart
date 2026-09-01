import 'package:daftar/application/ledger/aggregate_balances_by_currency.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_mutation_trigger.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archived_ledger_providers.g.dart';

const String _archivedVaultSummaryContactId = 'archived-vault-total';

@riverpod
Stream<List<Ledger>> archivedLedgers(Ref ref) {
  return ref.watch(getArchivedLedgersUseCaseProvider).execute();
}

@riverpod
int? archivedLedgerCount(Ref ref) {
  return ref.watch(archivedLedgersProvider).maybeWhen(
        data: (ledgers) => ledgers.length,
        orElse: () => null,
      );
}

@riverpod
Stream<List<ContactBalance>> archivedVaultBalances(Ref ref) {
  return ref.watch(getArchivedLedgersUseCaseProvider).execute().asyncMap(
    (ledgers) async {
      if (ledgers.isEmpty) {
        return const <ContactBalance>[];
      }

      final useCase = ref.read(getLedgerBalanceSummaryUseCaseProvider);
      final balances = <ContactBalance>[];

      for (final ledger in ledgers) {
        final result = await useCase.execute(ledger.id);
        result.fold(
          (_) {},
          balances.addAll,
        );
      }

      return aggregateBalancesByCurrency(
        balances,
        summaryContactId: _archivedVaultSummaryContactId,
      );
    },
  );
}

@riverpod
Future<Either<Failure, CarryForwardPreview>> previewCarryForward(
  Ref ref,
  String sourceLedgerId,
  String targetLedgerId,
) {
  return ref.watch(previewCarryForwardUseCaseProvider).execute(
        sourceLedgerId: sourceLedgerId,
        targetLedgerId: targetLedgerId,
      );
}

@Riverpod(keepAlive: true)
class ArchiveLedgerController extends _$ArchiveLedgerController {
  String? _activeLedgerId;

  @override
  FutureOr<void> build() {}

  bool isUnarchiving(String ledgerId) =>
      state.isLoading && _activeLedgerId == ledgerId;

  bool isArchiving(String ledgerId) =>
      state.isLoading && _activeLedgerId == ledgerId;

  String? get activeLedgerId => _activeLedgerId;

  Future<Either<Failure, Ledger>> archive({
    required String ledgerId,
    ArchiveWithCarryForwardParams? carryForward,
  }) async {
    _activeLedgerId = ledgerId;
    state = const AsyncValue.loading();

    try {
      final result = await ref.read(archiveLedgerUseCaseProvider).execute(
            ledgerId: ledgerId,
            carryForward: carryForward,
          );

      state = result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (_) => const AsyncValue.data(null),
      );

      result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));

      return result;
    } on Object catch (error, stackTrace) {
      final failure = DatabaseFailure(
        'Failed to archive ledger: $error',
        code: 'database_error',
      );
      state = AsyncValue.error(failure, stackTrace);
      return Left(failure);
    } finally {
      _activeLedgerId = null;
    }
  }

  Future<Either<Failure, Ledger>> unarchive(String ledgerId) async {
    _activeLedgerId = ledgerId;
    state = const AsyncValue.loading();

    try {
      final result =
          await ref.read(unarchiveLedgerUseCaseProvider).execute(ledgerId);

      state = result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (_) => const AsyncValue.data(null),
      );

      result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));

      return result;
    } on Object catch (error, stackTrace) {
      final failure = DatabaseFailure(
        'Failed to unarchive ledger: $error',
        code: 'database_error',
      );
      state = AsyncValue.error(failure, stackTrace);
      return Left(failure);
    } finally {
      _activeLedgerId = null;
    }
  }
}
