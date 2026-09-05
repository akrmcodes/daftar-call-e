import 'dart:async' show unawaited;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/providers/balance_providers.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/screens/contact/widgets/credit_limit_call_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared B-trigger entry after a committed debt save.
abstract final class CreditLimitBTrigger {
  /// Shows the HITL sheet when [warningLevel] is exceeded for a debt save.
  ///
  /// On accept, opens the credit-limit Collections Desk and navigates to the
  /// Closing Agent when not already there. Never auto-dials.
  static Future<void> offerAfterDebtSave({
    required BuildContext context,
    required WidgetRef ref,
    required String contactId,
    required TransactionType type,
    required CreditWarningLevel warningLevel,
  }) async {
    if (warningLevel != CreditWarningLevel.exceeded) {
      return;
    }
    if (type != TransactionType.debt) {
      return;
    }
    if (_shouldSkipPrompt(ref)) {
      return;
    }

    final contact = await _loadContact(ref, contactId);
    if (contact == null || !context.mounted) {
      return;
    }

    final metrics = await _loadDebtMetrics(ref, contact);
    if (metrics == null || !context.mounted) {
      return;
    }

    final accepted = await CreditLimitCallSheet.show(
      context,
      contactName: contact.name,
      outstandingMinor: metrics.outstandingMinor,
      creditLimitMinor: metrics.creditLimitMinor,
      currencyCode: metrics.currencyCode,
    );
    if (!accepted || !context.mounted) {
      return;
    }

    await ref
        .read(closingAgentControllerProvider.notifier)
        .openCreditLimitDesk(contactId);
    if (!context.mounted) {
      return;
    }

    final location = GoRouterState.of(context).uri.path;
    if (location != RouteNames.closingAgentPath) {
      unawaited(context.pushNamed(RouteNames.closingAgent));
    }
  }

  /// Presents the sheet for a pending agent prompt (same contact on screen).
  static Future<void> presentPendingPrompt({
    required BuildContext context,
    required WidgetRef ref,
    required String contactId,
  }) async {
    if (_shouldSkipPrompt(ref)) {
      ref
          .read(closingAgentControllerProvider.notifier)
          .clearCreditLimitPrompt();
      return;
    }

    final contact = await _loadContact(ref, contactId);
    if (contact == null) {
      ref
          .read(closingAgentControllerProvider.notifier)
          .clearCreditLimitPrompt();
      return;
    }

    final metrics = await _loadDebtMetrics(ref, contact);
    if (metrics == null) {
      ref
          .read(closingAgentControllerProvider.notifier)
          .clearCreditLimitPrompt();
      return;
    }

    if (!context.mounted) {
      return;
    }

    final accepted = await CreditLimitCallSheet.show(
      context,
      contactName: contact.name,
      outstandingMinor: metrics.outstandingMinor,
      creditLimitMinor: metrics.creditLimitMinor,
      currencyCode: metrics.currencyCode,
    );

    ref.read(closingAgentControllerProvider.notifier).clearCreditLimitPrompt();

    if (!accepted || !context.mounted) {
      return;
    }

    await ref
        .read(closingAgentControllerProvider.notifier)
        .openCreditLimitDesk(contactId);
  }

  static bool _shouldSkipPrompt(WidgetRef ref) {
    final phase = ref.read(closingAgentControllerProvider).phase;
    return phase == ClosingAgentPhase.ritualDesk ||
        phase == ClosingAgentPhase.ritualRunning;
  }

  static Future<Contact?> _loadContact(WidgetRef ref, String contactId) async {
    final result = await ref.read(contactByIdProvider(contactId).future);
    return result.fold((_) => null, (contact) => contact);
  }

  static Future<({int outstandingMinor, int creditLimitMinor, String currencyCode})?>
  _loadDebtMetrics(WidgetRef ref, Contact contact) async {
    final creditLimit = contact.creditLimit;
    if (creditLimit == null || creditLimit <= 0) {
      return null;
    }

    final balances =
        await ref.read(contactBalanceProvider(contact.id).future);
    final relevant = _selectRelevantBalance(balances, contact.creditCurrency);
    if (relevant == null) {
      return null;
    }

    final outstandingDebt = -relevant.netBalance;
    if (outstandingDebt <= 0) {
      return null;
    }

    return (
      outstandingMinor: outstandingDebt,
      creditLimitMinor: creditLimit,
      currencyCode: relevant.currencyCode,
    );
  }

  static ContactBalance? _selectRelevantBalance(
    List<ContactBalance> balances,
    String? creditCurrency,
  ) {
    if (balances.isEmpty) {
      return null;
    }

    if (creditCurrency != null && creditCurrency.trim().isNotEmpty) {
      final normalized = creditCurrency.trim().toUpperCase();
      for (final balance in balances) {
        if (balance.currencyCode.toUpperCase() == normalized) {
          return balance;
        }
      }
      return null;
    }

    var lowest = balances.first;
    for (final balance in balances.skip(1)) {
      if (balance.netBalance < lowest.netBalance) {
        lowest = balance;
      }
    }
    return lowest;
  }
}
