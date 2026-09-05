import 'dart:async';

import 'package:daftar/application/contact/compute_fifo_contact_aging.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/dual_rail_split.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:fpdart/fpdart.dart';

/// Builds the ranked overdue shortlist and dual-rail split on device.
///
/// Outstanding debt is [ContactBalance.netBalance] negative. Cloud Run is never
/// consulted. Empty list is success.
class GetCollectionsCandidatesUseCase {
  /// Creates the use case.
  const GetCollectionsCandidatesUseCase({
    required BalanceRepository balanceRepository,
    required TransactionRepository transactionRepository,
    required ContactRepository contactRepository,
  }) : _balanceRepository = balanceRepository,
       _transactionRepository = transactionRepository,
       _contactRepository = contactRepository;

  final BalanceRepository _balanceRepository;
  final TransactionRepository _transactionRepository;
  final ContactRepository _contactRepository;

  /// Returns ranked candidates with OutreachRail attached.
  ///
  /// Kill switch is **not** applied here — desk call-set uses region +
  /// allowlist + DNC. PSTN is gated later by RunBatchRecipientGuard.
  /// When [contactId] is set, only that contact is considered (B-trigger).
  Future<Either<Failure, List<CollectionsCandidate>>> execute({
    DateTime? asOf,
    Set<String> allowlist = const {},
    String allowlistRegion = 'US',
    String? contactId,
  }) async {
    final asOfTime = asOf ?? DateTime.now();

    final outreachResult =
        await _contactRepository.getContactsEligibleForCollectionsOutreach();
    if (outreachResult.isLeft()) {
      return Left(outreachResult.getLeft().toNullable()!);
    }
    final outreachContacts =
        outreachResult.getRight().toNullable() ?? const [];
    final filteredContacts = contactId == null || contactId.trim().isEmpty
        ? outreachContacts
        : outreachContacts
            .where((entry) => entry.contactId == contactId.trim())
            .toList(growable: false);
    if (filteredContacts.isEmpty) {
      return const Right(<CollectionsCandidate>[]);
    }

    final balances = await _balanceRepository.watchAllBalances().first;
    final balancesByContact = <String, List<ContactBalance>>{};
    for (final row in balances) {
      balancesByContact
          .putIfAbsent(row.contactId, () => <ContactBalance>[])
          .add(row);
    }

    final candidates = <CollectionsCandidate>[];
    for (final entry in filteredContacts) {
      final rows = balancesByContact[entry.contactId] ?? const <ContactBalance>[];
      final overdue = [
        for (final row in rows)
          if (row.netBalance < 0) row,
      ];
      if (overdue.isEmpty) {
        continue;
      }

      final contactResult = await _contactRepository.getById(entry.contactId);
      if (contactResult.isLeft()) {
        continue;
      }
      final contact = contactResult.getRight().toNullable();

      final txnsResult = await _transactionRepository.getRawTransactionsByContact(
        entry.contactId,
      );
      if (txnsResult.isLeft()) {
        continue;
      }
      final txns = txnsResult.getRight().toNullable() ?? const [];

      final slices = <FifoContactAging>[];
      for (final row in overdue) {
        final slice = computeFifoContactAging(
          transactions: txns,
          currencyCode: row.currencyCode,
          asOf: asOfTime,
        );
        if (slice != null) {
          slices.add(slice);
        }
      }
      final chosen = _pickSlice(
        slices: slices,
        creditCurrency: contact?.creditCurrency,
      );
      if (chosen == null) {
        continue;
      }

      ContactBalance? driftRow;
      for (final row in overdue) {
        if (row.currencyCode.trim().toUpperCase() == chosen.currencyCode) {
          driftRow = row;
          break;
        }
      }
      if (driftRow == null) {
        continue;
      }

      candidates.add(
        CollectionsCandidate(
          contactId: entry.contactId,
          name: entry.contactName,
          phone: contact?.phone ?? entry.phone,
          email: contact?.email ?? entry.email,
          ledgerId: entry.ledgerId,
          netBalance: driftRow.netBalance,
          currencyCode: chosen.currencyCode,
          ageDays: chosen.ageDays,
          toneBand: chosen.toneBand,
          daysSinceLastPayment: chosen.daysSinceLastPayment,
          daysSinceLastDebt: chosen.daysSinceLastDebt,
          doNotCall: contact?.doNotCall ?? entry.doNotCall,
        ),
      );
    }

    candidates.sort(_byAgeThenOwedThenName);

    final split = DualRailSplit.split(
      ranked: candidates,
      allowlistRegion: allowlistRegion,
      allowlist: allowlist,
    );

    return Right(split.ranked);
  }

  static FifoContactAging? _pickSlice({
    required List<FifoContactAging> slices,
    String? creditCurrency,
  }) {
    if (slices.isEmpty) {
      return null;
    }
    final preferred = creditCurrency?.trim().toUpperCase();
    if (preferred != null && preferred.isNotEmpty) {
      for (final slice in slices) {
        if (slice.currencyCode == preferred) {
          return slice;
        }
      }
    }
    final ranked = [...slices]
      ..sort((left, right) {
        final byAge = right.ageDays.compareTo(left.ageDays);
        if (byAge != 0) {
          return byAge;
        }
        return right.openMinor.compareTo(left.openMinor);
      });
    return ranked.first;
  }

  static int _byAgeThenOwedThenName(
    CollectionsCandidate left,
    CollectionsCandidate right,
  ) {
    final byAge = right.ageDays.compareTo(left.ageDays);
    if (byAge != 0) {
      return byAge;
    }
    final byOwed = right.owedMinor.compareTo(left.owedMinor);
    if (byOwed != 0) {
      return byOwed;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }
}
