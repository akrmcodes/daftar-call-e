import 'dart:async';

import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ledger mutation helpers for the home screen (reorder, delete, restore).
abstract final class HomeLedgerActions {
  const HomeLedgerActions._();

  /// Persists a grid reorder by updating sort order on changed ledgers.
  ///
  /// The reorderable grid package reports the final insertion index (same
  /// contract as its README): removeAt(oldIndex) then insert(newIndex) — NOT
  /// the ReorderableListView "newIndex - 1 when moving down" adjustment.
  static Future<void> reorder({
    required WidgetRef ref,
    required BuildContext context,
    required List<Ledger> ledgers,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (oldIndex == newIndex) {
      return;
    }

    final reordered = List<Ledger>.from(ledgers);
    final movedLedger = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, movedLedger);

    for (var index = 0; index < reordered.length; index++) {
      final entry = reordered[index];
      if (entry.sortOrder != index) {
        final updated = entry.copyWith(sortOrder: index);
        final result = await ref
            .read(ledgerControllerProvider.notifier)
            .updateLedger(updated);

        if (!context.mounted) {
          return;
        }

        result.fold(
          (failure) {
            unawaited(AppBottomSheet.showError(context, error: failure));
            return;
          },
          (_) {},
        );
      }
    }
  }

  static Future<Ledger?> delete({
    required WidgetRef ref,
    required BuildContext context,
    required String ledgerId,
  }) async {
    final result = await ref
        .read(ledgerControllerProvider.notifier)
        .deleteLedger(ledgerId);

    if (!context.mounted) {
      return null;
    }

    return result.fold(
      (failure) {
        unawaited(AppBottomSheet.showError(context, error: failure));
        return null;
      },
      (deletedLedger) => deletedLedger,
    );
  }

  static Future<void> restore({
    required WidgetRef ref,
    required BuildContext context,
    required String ledgerId,
    required VoidCallback onSuccess,
  }) async {
    final result = await ref
        .read(ledgerControllerProvider.notifier)
        .restoreLedger(ledgerId);

    if (!context.mounted) {
      return;
    }

    result.fold(
      (failure) {
        unawaited(AppBottomSheet.showError(context, error: failure));
      },
      (_) => onSuccess(),
    );
  }
}
