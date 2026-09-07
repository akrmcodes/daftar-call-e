import 'dart:async' show unawaited;

import 'package:daftar/app/router/app_router.dart';
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
  /// On accept, starts the credit-limit call session (one HITL) and navigates
  /// to the Closing Agent when not already there. Never auto-dials on dismiss.
  ///
  /// Uses the app [ProviderContainer] from the root overlay — never [ref]
  /// after an await. Add-debt callers pop their route before Prepare.
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

    final overlay = _overlayContext() ?? (context.mounted ? context : null);
    if (overlay == null || !overlay.mounted) {
      return;
    }
    final container = ProviderScope.containerOf(overlay, listen: false);
    final router = GoRouter.maybeOf(overlay);

    if (_shouldSkipPrompt(container)) {
      return;
    }

    final contact = await _loadContact(container, contactId);
    final sheetHost = _overlayContext();
    if (contact == null || sheetHost == null || !sheetHost.mounted) {
      return;
    }

    final metrics = await _loadDebtMetrics(container, contact);
    final sheetOverlay = _overlayContext();
    if (metrics == null || sheetOverlay == null || !sheetOverlay.mounted) {
      return;
    }

    await CreditLimitCallSheet.waitForKeyboardToSettle(sheetOverlay);
    if (!sheetOverlay.mounted) {
      return;
    }

    final accepted = await CreditLimitCallSheet.show(
      sheetOverlay,
      contactName: contact.name,
      outstandingMinor: metrics.outstandingMinor,
      creditLimitMinor: metrics.creditLimitMinor,
      currencyCode: metrics.currencyCode,
    );
    if (!accepted) {
      return;
    }

    await container
        .read(closingAgentControllerProvider.notifier)
        .startCreditLimitCallSession(contactId);
    _openClosingAgent(router);
  }

  /// Presents the sheet for a pending agent prompt (same contact on screen).
  static Future<void> presentPendingPrompt({
    required BuildContext context,
    required WidgetRef ref,
    required String contactId,
  }) async {
    final overlay = _overlayContext() ?? (context.mounted ? context : null);
    if (overlay == null || !overlay.mounted) {
      return;
    }
    final container = ProviderScope.containerOf(overlay, listen: false);

    if (_shouldSkipPrompt(container)) {
      container
          .read(closingAgentControllerProvider.notifier)
          .clearCreditLimitPrompt();
      return;
    }

    final contact = await _loadContact(container, contactId);
    if (contact == null) {
      container
          .read(closingAgentControllerProvider.notifier)
          .clearCreditLimitPrompt();
      return;
    }

    final metrics = await _loadDebtMetrics(container, contact);
    if (metrics == null) {
      container
          .read(closingAgentControllerProvider.notifier)
          .clearCreditLimitPrompt();
      return;
    }

    final sheetOverlay = _overlayContext();
    if (sheetOverlay == null || !sheetOverlay.mounted) {
      return;
    }

    await CreditLimitCallSheet.waitForKeyboardToSettle(sheetOverlay);
    if (!sheetOverlay.mounted) {
      return;
    }

    final accepted = await CreditLimitCallSheet.show(
      sheetOverlay,
      contactName: contact.name,
      outstandingMinor: metrics.outstandingMinor,
      creditLimitMinor: metrics.creditLimitMinor,
      currencyCode: metrics.currencyCode,
    );

    container
        .read(closingAgentControllerProvider.notifier)
        .clearCreditLimitPrompt();

    if (!accepted) {
      return;
    }

    await container
        .read(closingAgentControllerProvider.notifier)
        .startCreditLimitCallSession(contactId);
  }

  static BuildContext? _overlayContext() {
    final root = rootNavigatorKey.currentContext;
    if (root != null && root.mounted) {
      return root;
    }
    return null;
  }

  static void _openClosingAgent(GoRouter? router) {
    final nav = rootNavigatorKey.currentContext;
    final goRouter = router ??
        (nav != null && nav.mounted ? GoRouter.maybeOf(nav) : null);
    if (goRouter == null) {
      return;
    }
    final location = goRouter.state.uri.path;
    if (location != RouteNames.closingAgentPath) {
      unawaited(goRouter.pushNamed(RouteNames.closingAgent));
    }
  }

  static bool _shouldSkipPrompt(ProviderContainer container) {
    final phase = container.read(closingAgentControllerProvider).phase;
    return phase == ClosingAgentPhase.ritualDesk ||
        phase == ClosingAgentPhase.ritualRunning;
  }

  static Future<Contact?> _loadContact(
    ProviderContainer container,
    String contactId,
  ) async {
    final result = await container.read(contactByIdProvider(contactId).future);
    return result.fold((_) => null, (contact) => contact);
  }

  static Future<({int outstandingMinor, int creditLimitMinor, String currencyCode})?>
  _loadDebtMetrics(ProviderContainer container, Contact contact) async {
    final creditLimit = contact.creditLimit;
    if (creditLimit == null || creditLimit <= 0) {
      return null;
    }

    final balances =
        await container.read(contactBalanceProvider(contact.id).future);
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
