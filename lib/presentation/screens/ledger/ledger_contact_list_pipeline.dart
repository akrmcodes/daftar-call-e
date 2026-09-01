import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/value_objects/contact_with_summary.dart';

/// Display row combining summary data with optional full contact metadata.
class LedgerContactRow {
  const LedgerContactRow({
    required this.summary,
    required this.contact,
  });

  final ContactWithSummary summary;
  final Contact contact;

  String get contactId => summary.contactId;

  int get netBalance => LedgerContactSummarySelector.netBalance(summary);

  String get currencyCode =>
      LedgerContactSummarySelector.currencyCode(summary);

  int get transactionCount => summary.transactionCount;
}

/// Selects balance fields from a [ContactWithSummary].
abstract final class LedgerContactSummarySelector {
  const LedgerContactSummarySelector._();

  static ContactBalanceSummary? preferredBalance(ContactWithSummary summary) {
    if (summary.balances.isEmpty) {
      return null;
    }

    final preferredCurrency = summary.creditCurrency?.trim().toUpperCase();
    if (preferredCurrency != null && preferredCurrency.isNotEmpty) {
      for (final balance in summary.balances) {
        if (balance.currencyCode.trim().toUpperCase() == preferredCurrency) {
          return balance;
        }
      }
    }

    return summary.balances.first;
  }

  static int netBalance(ContactWithSummary summary) {
    return preferredBalance(summary)?.netBalance ?? 0;
  }

  static String currencyCode(ContactWithSummary summary) {
    return preferredBalance(summary)?.currencyCode ?? DbConstants.currencyYer;
  }
}

/// Memoized search → filter → sort pipeline for ledger contact lists.
class LedgerContactListPipeline {
  LedgerContactListPipeline({
    required List<ContactWithSummary> summaries,
    required Map<String, Contact> contactsById,
    required String searchQuery,
    required String currentFilter,
    required String currentSortMode,
  })  : _summaries = summaries,
        _contactsById = contactsById,
        _searchQuery = searchQuery,
        _currentFilter = currentFilter,
        _currentSortMode = currentSortMode;

  final List<ContactWithSummary> _summaries;
  final Map<String, Contact> _contactsById;
  final String _searchQuery;
  final String _currentFilter;
  final String _currentSortMode;

  List<LedgerContactRow>? _cachedRows;
  late Map<String, String> _normalizedNameCache;
  int? _lastInputKey;

  /// Returns filtered and sorted rows, recomputing only when inputs change.
  List<LedgerContactRow> compute() {
    final inputKey = Object.hash(
      Object.hashAll(_summaries),
      Object.hashAll(_contactsById.entries.map((e) => Object.hash(e.key, e.value.updatedAt))),
      _searchQuery,
      _currentFilter,
      _currentSortMode,
    );

    if (_cachedRows != null && _lastInputKey == inputKey) {
      return _cachedRows!;
    }

    _lastInputKey = inputKey;
    _normalizedNameCache = {
      for (final summary in _summaries)
        summary.contactId: _normalizeName(summary.name),
    };

    var pipeline = _summaries;
    if (_searchQuery.isNotEmpty) {
      final normalizedQuery = _normalizeName(_searchQuery);
      pipeline = pipeline
          .where(
            (summary) => _normalizedNameCache[summary.contactId]!
                .contains(normalizedQuery),
          )
          .toList(growable: false);
    }

    if (_currentFilter != _filterAll) {
      pipeline = pipeline.where((summary) {
        final balance = LedgerContactSummarySelector.netBalance(summary);
        switch (_currentFilter) {
          case _filterDebt:
            return balance < 0;
          case _filterCredit:
            return balance > 0;
          case _filterSettled:
            return balance == 0;
          default:
            return true;
        }
      }).toList(growable: false);
    }

    final sorted = List<ContactWithSummary>.of(pipeline)
      ..sort(_compareSummaries);

    _cachedRows = sorted
        .map(
          (summary) => LedgerContactRow(
            summary: summary,
            contact: _contactForSummary(summary),
          ),
        )
        .toList(growable: false);

    return _cachedRows!;
  }

  Contact _contactForSummary(ContactWithSummary summary) {
    return _contactsById[summary.contactId] ??
        Contact(
          id: summary.contactId,
          ledgerId: summary.ledgerId,
          name: summary.name,
          phone: summary.phone,
          avatarColor: summary.avatarColor,
          creditLimit: summary.creditLimit,
          creditCurrency: summary.creditCurrency,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
  }

  int _compareSummaries(ContactWithSummary left, ContactWithSummary right) {
    switch (_currentSortMode) {
      case _sortModeBalance:
        final leftBalance =
            LedgerContactSummarySelector.netBalance(left).abs();
        final rightBalance =
            LedgerContactSummarySelector.netBalance(right).abs();
        final balanceComparison = rightBalance.compareTo(leftBalance);
        if (balanceComparison != 0) {
          return balanceComparison;
        }
        return _compareByName(left, right);
      case _sortModeRecent:
        final leftUpdated = _contactsById[left.contactId]?.updatedAt;
        final rightUpdated = _contactsById[right.contactId]?.updatedAt;
        if (leftUpdated != null && rightUpdated != null) {
          final recentComparison = rightUpdated.compareTo(leftUpdated);
          if (recentComparison != 0) {
            return recentComparison;
          }
        }
        return _compareByName(left, right);
      case _sortModeName:
      default:
        return _compareByName(left, right);
    }
  }

  int _compareByName(ContactWithSummary left, ContactWithSummary right) {
    final nameComparison = _normalizeName(left.name).compareTo(
      _normalizeName(right.name),
    );
    if (nameComparison != 0) {
      return nameComparison;
    }

    return left.contactId.compareTo(right.contactId);
  }

  static String _normalizeName(String value) {
    return value.normalizeArabic().toLowerCase();
  }
}

const String _sortModeName = 'name';
const String _sortModeBalance = 'balance';
const String _sortModeRecent = 'recent';

const String _filterAll = 'all';
const String _filterDebt = 'debt';
const String _filterCredit = 'credit';
const String _filterSettled = 'settled';
