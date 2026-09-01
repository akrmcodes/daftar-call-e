import 'dart:async';

import 'package:daftar/application/transaction/quick_add_name_resolver.dart';
import 'package:daftar/application/transaction/quick_add_state.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quick_add_controller.g.dart';

const Duration _nameSearchDebounce = Duration(milliseconds: 300);

/// State controller for the center-FAB quick-add transaction sheet.
///
/// Debounces name search, calls SearchContactsUseCase, and applies
/// QuickAddNameResolver (Mohammed logic) for ledger auto-selection.
@riverpod
class QuickAddController extends _$QuickAddController {
  Timer? _nameDebounceTimer;
  int _nameSearchGeneration = 0;

  @override
  QuickAddState build() {
    ref
      ..onDispose(() => _nameDebounceTimer?.cancel())
      ..listen(ledgersProvider, (previous, next) {
        final ledgers = next.value;
        if (ledgers == null) {
          return;
        }

        state = state.copyWith(
          availableLedgers: ledgers,
          selectedLedgerId: QuickAddNameResolver.reconcileSelectedLedger(
            current: state.selectedLedgerId,
            resolution: state.accountResolution,
            availableLedgers: ledgers,
            matchedContacts: state.matchedContacts,
          ),
        );
      });

    final ledgers = ref.watch(ledgersProvider).value ?? const [];
    final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
    return QuickAddState.initial(
      availableLedgers: ledgers,
      defaultCurrency: settings.defaultCurrency,
    );
  }

  /// Updates the typed name and runs a debounced contact search.
  void onNameChanged(String query) {
    final trimmed = query.trim();

    if (state.selectedContactId != null) {
      final selected = _findContactById(state.selectedContactId!);
      if (selected != null &&
          trimmed.normalizeArabic() !=
              selected.name.trim().normalizeArabic()) {
        state = state.copyWith(clearSelectedContactId: true);
      }
    }

    state = state.copyWith(nameQuery: query, clearSearchFailure: true);

    _nameDebounceTimer?.cancel();

    if (trimmed.isEmpty) {
      _nameSearchGeneration++;
      state = state.copyWith(
        matchedContacts: const [],
        isSearchingName: false,
        accountResolution: QuickAddAccountResolution.idle,
        clearSelectedContactId: true,
        selectedLedgerId: QuickAddState.primaryLedgerId(state.availableLedgers),
      );
      return;
    }

    state = state.copyWith(isSearchingName: true);
    final generation = ++_nameSearchGeneration;

    _nameDebounceTimer = Timer(_nameSearchDebounce, () {
      unawaited(_searchContacts(trimmed, generation));
    });
  }

  /// Applies a tapped autocomplete suggestion and locks ledger resolution.
  void selectSuggestedContact(Contact match) {
    _nameDebounceTimer?.cancel();
    _nameSearchGeneration++;

    final resolution = QuickAddNameResolver.resolve(
      matches: [match],
      availableLedgers: state.availableLedgers,
    );

    state = state.copyWith(
      nameQuery: match.name,
      matchedContacts: [match],
      selectedContactId: match.id,
      accountResolution: resolution.mode,
      selectedLedgerId: resolution.selectedLedgerId ?? match.ledgerId,
      isSearchingName: false,
      clearSearchFailure: true,
    );
  }

  /// Sets the optional item/category note.
  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  /// Sets the ISO currency code for the transaction amount.
  void setSelectedCurrencyCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return;
    }
    state = state.copyWith(selectedCurrencyCode: normalized);
  }

  Future<void> _searchContacts(String query, int generation) async {
    final result = await ref.read(searchContactsUseCaseProvider).execute(
          query,
          excludeUserArchivedLedgers: true,
        );

    if (!ref.mounted || generation != _nameSearchGeneration) {
      return;
    }

    result.fold(
      (failure) {
        state = state.copyWith(
          isSearchingName: false,
          searchFailure: failure,
        );
      },
      (hits) {
        if (state.selectedContactId != null) {
          return;
        }

        final matches = hits.map((hit) => hit.contact).toList(growable: false);
        final resolution = QuickAddNameResolver.resolve(
          matches: matches,
          availableLedgers: state.availableLedgers,
        );

        state = state.copyWith(
          isSearchingName: false,
          matchedContacts: matches,
          accountResolution: resolution.mode,
          selectedLedgerId: resolution.selectedLedgerId,
          clearSelectedLedgerId: resolution.selectedLedgerId == null,
        );
      },
    );
  }

  Contact? _findContactById(String contactId) {
    for (final contact in state.matchedContacts) {
      if (contact.id == contactId) {
        return contact;
      }
    }
    return null;
  }

  /// Sets the transaction amount in smallest currency units.
  void setAmountMinorUnits(int? amountMinorUnits) {
    if (amountMinorUnits == null) {
      state = state.copyWith(clearAmount: true);
      return;
    }
    state = state.copyWith(amountMinorUnits: amountMinorUnits);
  }

  /// Sets credit (له) vs debit (عليه).
  void setIsCredit({required bool isCredit}) {
    state = state.copyWith(
      transactionType:
          isCredit ? TransactionType.payment : TransactionType.debt,
    );
  }

  /// User-selected ledger (required when [QuickAddAccountResolution.multiLedgerPick]).
  void selectLedger(String ledgerId) {
    if (!state.availableLedgers.any((ledger) => ledger.id == ledgerId)) {
      return;
    }
    state = state.copyWith(selectedLedgerId: ledgerId);
  }

  /// Resets the sheet to its initial values (e.g. on dismiss).
  void reset() {
    _nameDebounceTimer?.cancel();
    _nameSearchGeneration++;
    final ledgers = state.availableLedgers;
    final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
    state = QuickAddState.initial(
      availableLedgers: ledgers,
      defaultCurrency: settings.defaultCurrency,
    );
  }
}
