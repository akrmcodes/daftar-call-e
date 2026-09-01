import 'dart:async';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/screens/home/home_ledger_actions.dart';
import 'package:daftar/presentation/screens/home/widgets/add_ledger_sheet.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card.dart';
import 'package:daftar/presentation/screens/home/widgets/edit_ledger_sheet.dart';
import 'package:daftar/presentation/screens/home/widgets/home_ledger_slivers.dart';
import 'package:daftar/presentation/screens/home/widgets/home_my_ledgers_header.dart';
import 'package:daftar/presentation/screens/home/widgets/home_search_sheet_content.dart';
import 'package:daftar/presentation/screens/home/widgets/home_sliver_app_bar.dart';
import 'package:daftar/presentation/screens/home/widgets/home_undo_delete_snackbar.dart';
import 'package:daftar/presentation/screens/ledger/widgets/financial_close_wizard_sheet.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_sliver_refresh.dart';
import 'package:daftar/presentation/shared/widgets/ledger_delete_confirm_sheet.dart';
import 'package:daftar/presentation/widgets/premium/ledger_archiving_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _onRefresh() => daftarRefreshWithPerceivedDelay(() async {
    ref.invalidate(ledgersProvider);
    await ref.read(ledgersProvider.future);
  });

  Future<void> _handleReorder(
    List<Ledger> ledgers,
    int oldIndex,
    int newIndex,
  ) => HomeLedgerActions.reorder(
    ref: ref,
    context: context,
    ledgers: ledgers,
    oldIndex: oldIndex,
    newIndex: newIndex,
  );

  Future<void> _showEditLedgerSheet(Ledger ledger) =>
      EditLedgerSheet.show(context, ledger: ledger);

  Future<void> _showArchiveWizard(Ledger ledger) async {
    final unlocked = await LedgerArchivingGate.ensureUnlocked(context, ref);
    if (!unlocked || !mounted) {
      return;
    }
    await FinancialCloseWizardSheet.show(context, sourceLedger: ledger);
  }

  Future<void> _showAddLedgerSheet() => AddLedgerSheet.show(context);

  void _showSearchSheet() {
    final l10n = AppLocalizations.of(context)!;

    unawaited(
      AppBottomSheet.show<void>(
        context,
        title: l10n.searchHint,
        maxHeightFactor: 0.85,
        child: HomeSearchSheetContent(
          onContactTap: _navigateToContact,
        ),
      ),
    );
  }

  void _navigateToContact(Contact contact) {
    unawaited(Navigator.of(context).maybePop());
    unawaited(
      context.pushNamed(
        RouteNames.contactDetail,
        pathParameters: {
          RouteNames.contactIdParam: contact.id,
        },
      ),
    );
  }

  Future<void> _handleDeleteLedger(Ledger ledger) async {
    final l10n = AppLocalizations.of(context)!;
    final contactsCount = ref.read(contactCountProvider(ledger.id)).value ?? 0;
    final confirmed = await LedgerDeleteConfirmSheet.show(
      context,
      ledgerName: ledger.name,
      contactsCount: contactsCount,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final deletedLedger = await HomeLedgerActions.delete(
      ref: ref,
      context: context,
      ledgerId: ledger.id,
    );

    if (!mounted || deletedLedger == null) {
      return;
    }

    showHomeUndoDeleteSnackBar(
      context: context,
      l10n: l10n,
      colors: context.colorScheme,
      onUndo: () => unawaited(_restoreLedger(deletedLedger)),
    );
  }

  Future<void> _restoreLedger(Ledger ledger) => HomeLedgerActions.restore(
    ref: ref,
    context: context,
    ledgerId: ledger.id,
    onSuccess: () => unawaited(HapticService.undoTapped()),
  );

  void _openLedgerDetail(Ledger ledger) {
    unawaited(
      context.pushNamed(
        RouteNames.ledgerDetail,
        pathParameters: {
          RouteNames.ledgerIdParam: ledger.id,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final bottomScrollClearance =
        context.bottomPadding + AppDimensions.shellDockScrollInset;
    final asyncLedgers = ref.watch(ledgersProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          DaftarSliverRefreshControl(onRefresh: _onRefresh),
          HomeSliverAppBar(
            onSearchTap: _showSearchSheet,
          ),
          const SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              AppDimensions.spacingLg,
              AppDimensions.pagePaddingH,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: BalanceCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: HomeMyLedgersHeader(
              onAddLedgerTap: _showAddLedgerSheet,
            ),
          ),
          ...asyncLedgers.when(
            loading: HomeLedgerSlivers.loading,
            error: (_, _) => HomeLedgerSlivers.error(
              l10n: l10n,
              colors: colors,
            ),
            data: (ledgers) {
              if (ledgers.isEmpty) {
                return HomeLedgerSlivers.empty(
                  l10n: l10n,
                  onAddLedger: _showAddLedgerSheet,
                );
              }

              return HomeLedgerSlivers.populated(
                context: context,
                ledgers: ledgers,
                onReorder: (oldIndex, newIndex) => unawaited(
                  _handleReorder(ledgers, oldIndex, newIndex),
                ),
                onEdit: (ledger) => unawaited(_showEditLedgerSheet(ledger)),
                onArchive: (ledger) => unawaited(_showArchiveWizard(ledger)),
                onDelete: (ledger) => unawaited(_handleDeleteLedger(ledger)),
                onTap: _openLedgerDetail,
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: bottomScrollClearance),
          ),
        ],
      ),
    );
  }
}
