import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/localized_error_content.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/core/utils/pdf_storage_service.dart';
import 'package:daftar/core/utils/statement_share.dart';
import 'package:daftar/core/utils/whatsapp_util.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/presentation/providers/balance_providers.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/permissions_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:daftar/presentation/providers/transaction_providers.dart';
import 'package:daftar/presentation/screens/contact/widgets/archived_ledger_read_only_banner.dart';
import 'package:daftar/presentation/screens/contact/widgets/balance_summary.dart';
import 'package:daftar/presentation/screens/contact/widgets/contact_pending_promise_banner.dart';
import 'package:daftar/presentation/screens/contact/widgets/credit_limit_banner.dart';
import 'package:daftar/presentation/screens/contact/widgets/export_progress_overlay.dart';
import 'package:daftar/presentation/screens/contact/widgets/show_edit_contact_sheet.dart';
import 'package:daftar/presentation/screens/contact/widgets/transaction_list_tile.dart';
import 'package:daftar/presentation/screens/transaction/widgets/add_transaction_dialog.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_sliver_refresh.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:daftar/presentation/shared/widgets/empty_state.dart';
import 'package:daftar/presentation/shared/widgets/skeleton_contact_vault.dart';
import 'package:daftar/presentation/shared/widgets/skeleton_transaction_list.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contact detail screen with a premium header and transaction list.
class ContactDetailScreen extends ConsumerStatefulWidget {
  /// Creates a contact detail screen for the provided contact id.
  const ContactDetailScreen({
    required this.contactId,
    this.contact,
    super.key,
  });

  final String contactId;
  final Contact? contact;

  @override
  ConsumerState<ContactDetailScreen> createState() =>
      _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  late final ScrollController _scrollController;
  final GlobalKey _transactionsSectionKey = GlobalKey();

  /// Vertical space reserved below the scroll body for the sticky share bar
  /// (padding + button + hairline), excluding the bottom safe-area inset
  /// (which is added separately when computing scroll padding).
  static const double _shareBarContentHeight = 80;

  /// Extra scroll extent so the last transaction clears the FAB above the bar.
  static const double _fabStackReserve = 72;

  /// Prefetch threshold — start loading when this far from the bottom.
  static const double _prefetchDistance = 1000;

  /// Footer spinner height during pagination fetch (outside fixed tile extents).
  static const double _paginationFooterExtent = 48;

  /// Export-in-flight flag. Disables the share button so a double-tap can
  /// never spawn two PDF isolates / two overlays for the same contact.
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_maybeLoadMoreTransactions);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMoreTransactions)
      ..dispose();
    super.dispose();
  }

  void _scheduleLoadMoreCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeLoadMoreTransactions();
      }
    });
  }

  /// Triggers the next paginated fetch when the viewport nears the list end.
  ///
  /// Called from [ScrollController] listeners, [NotificationListener], and
  /// post-frame callbacks after transaction/count updates. Skips when the
  /// total count is not yet known — passing `0` would permanently cap
  /// [TransactionLimit] because `state >= totalCount`.
  void _maybeLoadMoreTransactions() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }

    final remainingScroll = position.maxScrollExtent - position.pixels;
    if (remainingScroll > _prefetchDistance) {
      return;
    }

    final totalCount = ref.read(transactionCountProvider(contactId)).value;
    if (totalCount == null) {
      return;
    }

    final currentLimit = ref.read(transactionLimitProvider(contactId));
    if (currentLimit >= totalCount) {
      return;
    }

    ref
        .read(transactionLimitProvider(contactId).notifier)
        .loadMore(totalCount: totalCount);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _maybeLoadMoreTransactions();
    }
    return false;
  }

  String get contactId => widget.contactId;
  Contact? get contact => widget.contact;

  Future<void> _onRefreshContactDetail() =>
      daftarRefreshWithPerceivedDelay(() async {
        final id = contactId;
        ref
          ..invalidate(contactByIdProvider(id))
          ..invalidate(contactBalanceProvider(id))
          ..invalidate(paginatedTransactionsProvider(id))
          ..invalidate(transactionCountProvider(id));
        await ref.read(contactByIdProvider(id).future);
      });

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(paginatedTransactionsProvider(contactId), (_, _) {
        _scheduleLoadMoreCheck();
      })
      ..listen(transactionCountProvider(contactId), (_, _) {
        _scheduleLoadMoreCheck();
      });

    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // ── Resolve the contact from provider or route extra ────────
    final asyncContact = ref.watch(contactByIdProvider(contactId));
    final contactResult = asyncContact.asData?.value;
    final resolvedContact =
        contactResult?.fold(
          (_) => contact,
          (dbContact) => dbContact,
        ) ??
        contact;
    final hasContactFailure =
        contactResult?.fold(
          (_) => true,
          (dbContact) => false,
        ) ??
        false;

    if (resolvedContact == null) {
      if (hasContactFailure || asyncContact.hasError) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: EmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.contactDetails,
            subtitle: l10n.loadingError,
            ctaLabel: l10n.retry,
            ctaIcon: Icons.refresh_rounded,
            iconColor: AppColors.error,
            onCtaPressed: () {
              ref.invalidate(contactByIdProvider(contactId));
            },
          ),
        );
      }

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            DaftarSliverRefreshControl(
              onRefresh: _onRefreshContactDetail,
            ),
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: theme.scaffoldBackgroundColor,
              automaticallyImplyLeading: false,
              leadingWidth: 72,
              leading: _LuxuryBackButton(
                isDark: isDark,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed(RouteNames.home);
                  }
                },
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.pagePaddingH,
                  AppDimensions.spacingSm,
                  AppDimensions.pagePaddingH,
                  0,
                ),
                child: Column(
                  children: [
                    SkeletonContactVaultCard(),
                    SizedBox(height: AppDimensions.spacingXl),
                    SkeletonTransactionList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final displayContact = resolvedContact;

    // ── Resolve balance data from reactive stream ──────────────
    final asyncBalances = ref.watch(contactBalanceProvider(contactId));
    final balances = asyncBalances.asData?.value ?? const <ContactBalance>[];
    final asyncSettings = ref.watch(appSettingsProvider);
    final appDefaultCurrency =
        asyncSettings.asData?.value.defaultCurrency ?? DbConstants.currencyYer;
    final primaryBalance = balances.isNotEmpty ? balances.first : null;
    final currencyCode =
        primaryBalance?.currencyCode ?? displayContact.creditCurrency ?? 'YER';
    final isMultiCurrencyEnabled =
        asyncSettings.asData?.value.isMultiCurrencyEnabled ?? false;
    final newTransactionCurrencyCode = _resolveNewTransactionCurrency(
      contact: displayContact,
      balances: balances,
      appDefaultCurrency: appDefaultCurrency,
      isMultiCurrencyEnabled: isMultiCurrencyEnabled,
    );

    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final hasPhone = _hasPhoneNumber(displayContact.phone);
    final isReadOnly =
        ref.watch(isContactLedgerReadOnlyProvider(contactId)).value ?? false;
    final canEditTransactions =
        ref.watch(canPerformProvider(WorkspacePermission.editTransactions)).value ??
            true;
    final asyncTransactions = ref.watch(paginatedTransactionsProvider(contactId));
    final isTransactionsEmpty = asyncTransactions.hasValue &&
        (asyncTransactions.asData?.value.isEmpty ?? false);
    final showTransactionFab = !isReadOnly &&
        canEditTransactions &&
        !isTransactionsEmpty;
    final fabReserve = showTransactionFab ? _fabStackReserve : 0.0;
    final listBottomInset =
        bottomSafe + _shareBarContentHeight + fabReserve;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: showTransactionFab
          ? _LuxuryAddTransactionFab(
              isDark: isDark,
              label: l10n.addTransaction,
              onPressed: () async {
                await showAddTransactionDialog(
                  context,
                  contactId: contactId,
                  contactName: displayContact.name,
                  defaultCurrency: newTransactionCurrencyCode,
                );
              },
            )
          : null,
      bottomNavigationBar: _StatementBottomBar(
        label: l10n.exportStatement,
        dateRangeLabel: l10n.exportStatementDateRange,
        enabled: !_isExporting,
        isLoading: _isExporting,
        isDark: isDark,
        onPressed: () async {
          await _exportStatement(
            context: context,
            contact: displayContact,
            balances: balances,
            fallbackCurrencyCode: newTransactionCurrencyCode,
          );
        },
        onExportDateRange: () async {
          if (_isExporting) return;
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
            helpText: l10n.exportStatement,
          );
          if (!context.mounted || range == null) return;
          await _exportStatement(
            context: context,
            contact: displayContact,
            balances: balances,
            fallbackCurrencyCode: newTransactionCurrencyCode,
            selectedRange: range,
          );
        },
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
          DaftarSliverRefreshControl(
            onRefresh: _onRefreshContactDetail,
          ),
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            automaticallyImplyLeading: false,
            leadingWidth: 72,
            leading: _LuxuryBackButton(
              isDark: isDark,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.home);
                }
              },
            ),
            actions: [
              if (!isReadOnly)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: _LuxuryToolbarIcon(
                    isDark: isDark,
                    semanticsLabel: l10n.editContact,
                    icon: Icons.edit_rounded,
                    onPressed: () async {
                      final updatedContact = await showEditContactSheet(
                        context,
                        contact: displayContact,
                      );
                      if (updatedContact != null) {
                        ref.invalidate(contactByIdProvider(contactId));
                      }
                    },
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.pagePaddingH,
                AppDimensions.spacingSm,
                AppDimensions.pagePaddingH,
                0,
              ),
              child: Column(
                children: [
                  _ClientVaultHeroCard(
                    contactId: contactId,
                    contactName: displayContact.name,
                    phone: displayContact.phone,
                    avatarColorHex: displayContact.avatarColor,
                    isDark: isDark,
                    callLabel: l10n.call,
                    whatsAppLabel: l10n.openWhatsApp,
                    onCall: hasPhone
                        ? () => _launchCall(context, displayContact.phone)
                        : null,
                    onWhatsApp: hasPhone
                        ? () => _launchWhatsApp(context, displayContact.phone)
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                ],
              ),
            ),
          ),
          if (isReadOnly) const ArchivedLedgerReadOnlyBanner(),
          CreditLimitBanner(
            contactId: contactId,
            contact: displayContact,
            balances: balances,
          ),
          ContactPendingPromiseBanner(contactId: contactId),
          if (balances.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingXl),
            ),
            SliverToBoxAdapter(
              child: BalanceSummary(
                balances: balances,
                isDark: isDark,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.spacingXl),
            ),
          ],
          // ── Transaction List (stream-driven) ────────────
          ..._buildTransactionSliver(
            context,
            l10n,
            colors,
            isDark,
            currencyCode,
            displayContact.name,
            listBottomInset: listBottomInset,
            isReadOnly: isReadOnly,
            canAddTransaction: !isReadOnly && canEditTransactions,
            newTransactionCurrencyCode: newTransactionCurrencyCode,
          ),
        ],
        ),
      ),
    );
  }

  /// Builds the transaction list slivers based on stream state.
  ///
  /// Uses [paginatedTransactionsProvider] with `asData?.value` to ensure
  /// seamless scroll retention when loading more pages. The skeleton
  /// loading state is only shown on the very first load (no previous data).
  List<Widget> _buildTransactionSliver(
    BuildContext screenContext,
    AppLocalizations l10n,
    ColorScheme colors,
    bool isDark,
    String currencyCode,
    String contactName, {
    required double listBottomInset,
    required bool isReadOnly,
    required bool canAddTransaction,
    required String newTransactionCurrencyCode,
  }) {
    final asyncTransactions = ref.watch(
      paginatedTransactionsProvider(contactId),
    );
    final currentLimit = ref.watch(transactionLimitProvider(contactId));
    final totalCount = ref.watch(transactionCountProvider(contactId)).value;
    final swipeEnabled = !isReadOnly &&
        (ref.watch(appSettingsProvider).asData?.value.isSwipeToDeleteEnabled ??
            false);

    // State transition contract for pagination:
    //
    // Initial load:   hasValue=false, isLoading=true  → show skeleton
    // Data arrived:   hasValue=true,  isLoading=false → show list
    // Limit changed:  hasValue=true,  isLoading=true  → show EXISTING list
    //                 (previous data retained, no widget tree change)
    // New data:       hasValue=true,  isLoading=false → show updated list
    //
    // The critical invariant: once hasValue is true, we NEVER return
    // the skeleton/error/empty slivers that would destroy the SliverList.
    // This guarantees zero intermediate frames with a different widget tree.
    final hasData = asyncTransactions.hasValue;
    final transactions = hasData ? asyncTransactions.value : null;
    final isInitialLoading = !hasData && asyncTransactions.isLoading;
    final hasError = asyncTransactions.hasError && !hasData;
    final hasMore =
        totalCount != null && currentLimit < totalCount;
    final isLoadingMore = hasData && asyncTransactions.isLoading && hasMore;

    if (isInitialLoading) {
      return [
        const SliverToBoxAdapter(
          child: SkeletonTransactionList(),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: listBottomInset),
        ),
      ];
    }

    if (hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: listBottomInset),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: AppColors.error.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      l10n.transactionsError,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    if (transactions == null || transactions.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: listBottomInset),
            child: EmptyState(
              icon: Icons.receipt_long_rounded,
              title: l10n.noTransactionsYet,
              subtitle: l10n.emptyStateSubtitle,
              ctaLabel: l10n.addTransaction,
              ctaIcon: Icons.add_rounded,
              onCtaPressed: canAddTransaction
                  ? () {
                      unawaited(
                        showAddTransactionDialog(
                          screenContext,
                          contactId: contactId,
                          contactName: contactName,
                          defaultCurrency: newTransactionCurrencyCode,
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ),
      ];
    }

    return [
      // Section header
      SliverToBoxAdapter(
        child: Padding(
          key: _transactionsSectionKey,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.pagePaddingH,
            AppDimensions.spacingMd,
            AppDimensions.pagePaddingH,
            AppDimensions.spacingSm,
          ),
          child: Text(
            l10n.recentTransactions,
            style: AppTextStyles.titleSmall.copyWith(
              color: isDark
                  ? AppColors.inkSecondary
                  : AppColors.inkSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 120),
              curve: AppMotion.curveEmphasized,
            )
            .slideY(
              begin: 0.04,
              end: 0,
              duration: const Duration(milliseconds: 400),
              delay: const Duration(milliseconds: 120),
              curve: AppMotion.curveEmphasized,
            ),
      ),
      // Transaction list with stable keys and findChildIndexCallback.
      //
      // Why not SliverList.separated?
      // It creates an anonymous SliverChildBuilderDelegate that does NOT
      // expose `findChildIndexCallback`. Without it, Flutter cannot map
      // existing keyed children to new indices when the list grows,
      // causing a full element tree rebuild and scroll jerk.
      //
      // The interleaved item/separator pattern (itemCount * 2 - 1) lets
      // us keep separators while using a custom delegate.
      //
      // Date group headers are composed INSIDE each even-index widget
      // using a Column. This keeps the flat List<Transaction> structure
      // and the findChildIndexCallback contract completely intact:
      // rawIndex == i * 2 always maps to transactions[i].
      _ContactTransactionListSliver(
        contactId: contactId,
        screenContext: screenContext,
        transactions: transactions,
        l10n: l10n,
        isDark: isDark,
        currencyCode: currencyCode,
        contactName: contactName,
        swipeEnabled: swipeEnabled,
        isReadOnly: isReadOnly,
        getRelativeDateGroup: _getRelativeDateGroup,
        onTransactionDeleted: (transaction) => _showTransactionUndoSnackBar(
          context: screenContext,
          transaction: transaction,
        ),
      ),
      if (isLoadingMore)
        SliverToBoxAdapter(
          child: SizedBox(
            height: _paginationFooterExtent,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? AppColors.lapis400 : AppColors.lapis500,
                ),
              ),
            ),
          ),
        ),
      // Bottom padding: safe area + sticky share bar + FAB stack.
      SliverToBoxAdapter(
        child: SizedBox(height: listBottomInset),
      ),
    ];
  }

  Future<void> _exportStatement({
    required BuildContext context,
    required Contact contact,
    required List<ContactBalance> balances,
    required String fallbackCurrencyCode,
    DateTimeRange? selectedRange,
  }) async {
    if (_isExporting) return;

    // Capture context-bound dependencies BEFORE the first await so subsequent
    // post-await usage cannot reference a stale BuildContext.
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;

    setState(() => _isExporting = true);

    final overlayCtrl = ExportProgressOverlay.show(
      context,
      title: l10n.exportStatement,
    );

    String? userMessage;
    Object? exportError;
    try {
      // ── Phase A: Fetch transactions ──────────────────────────
      final List<Transaction> allTransactions;
      try {
        overlayCtrl.update(0.05, l10n.pdfPreparingData);
        final result = await ref
            .read(getAllTransactionsForContactUseCaseProvider)
            .execute(contactId);
        allTransactions = result.fold(
          (failure) => throw _ExportFlowFailure(failure),
          (transactions) => transactions,
        );
      } on _ExportFlowFailure {
        rethrow;
      } on _PdfExportException {
        rethrow;
      } on Object {
        throw _PdfExportException.fetch('');
      }

      final transactionsForPdf = selectedRange == null
          ? allTransactions
          : _transactionsInStatementRange(allTransactions, selectedRange);

      if (selectedRange != null && transactionsForPdf.isEmpty) {
        overlayCtrl.dismiss();
        userMessage = l10n.pdfNoTransactionsInRange;
      } else {
        // ── Phase B: Generate PDF bytes (isolate) ────────────────
        final Uint8List pdfBytes;
        try {
          if (!context.mounted) {
            overlayCtrl.dismiss();
            return;
          }
          final periodLine = selectedRange == null
              ? null
              : _formatStatementPeriodLine(context, l10n, selectedRange);

          final fallbackBalance = ContactBalance(
            contactId: contact.id,
            currencyCode: fallbackCurrencyCode,
            totalDebt: 0,
            totalPayment: 0,
            netBalance: 0,
            lastUpdatedAt: DateTime.now().toUtc(),
          );
          final primaryBalance = balances.isNotEmpty
              ? balances.first
              : fallbackBalance;

          final effectiveProfile = await ref
              .read(resolvePdfMerchantProfileUseCaseProvider)
              .execute();

          pdfBytes = await PdfGenerator.generateContactStatement(
            contact: contact,
            contactBalance: primaryBalance,
            transactions: transactionsForPdf,
            isRtl: isRtl,
            applicationName: l10n.appTitle,
            labelStatement: l10n.statement,
            labelContactName: l10n.name,
            labelGeneratedOn: l10n.generatedOn,
            labelTotalDebt: l10n.totalDebt,
            labelTotalPayment: l10n.totalPayment,
            labelNetBalance: l10n.netBalance,
            labelDate: l10n.date,
            labelDetails: l10n.statementDetails,
            labelDebt: l10n.debt,
            labelPayment: l10n.payment,
            labelRunningBalance: l10n.runningBalance,
            labelCurrency: l10n.currency,
            labelPage: l10n.page,
            msgPreparing: l10n.pdfPreparingData,
            msgGrouping: l10n.pdfGroupingTransactions,
            msgBuilding: l10n.pdfBuildingLayout,
            msgRendering: l10n.pdfRendering,
            onProgress: overlayCtrl.update,
            statementPeriodText: periodLine,
            merchantProfile: effectiveProfile,
          );
        } on TimeoutException {
          throw _PdfExportException.timeout();
        } on Object {
          throw _PdfExportException.render('');
        }

        // ── Phase C: Save to local storage ───────────────────────
        final hasSpace =
            await ref.read(storageServiceProvider).hasEnoughSpace();
        if (!hasSpace) {
          throw _ExportFlowFailure(const StorageFullFailure());
        }

        final File savedFile;
        try {
          overlayCtrl.update(0.95, l10n.pdfSaving);
          savedFile = await PdfStorageService.saveStatement(
            pdfBytes: pdfBytes,
            contactName: contact.name,
          );
        } on Object {
          throw _PdfExportException.save('');
        }

        // ── Phase D: Complete + share ─────────────────────────────
        overlayCtrl.complete(l10n.pdfComplete);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        overlayCtrl.dismiss();

        try {
          await StatementShare.shareStatementPdf(
            file: XFile(savedFile.path),
            shareTitle: l10n.shareStatement,
            shareSubject: l10n.statementShareSubject(contact.name),
          );
        } on Object {
          throw _PdfExportException.share('');
        }
      }
    } on _ExportFlowFailure catch (e, st) {
      developer.log('Export Error', error: e.failure, stackTrace: st);
      exportError = e.failure;
    } on _PdfExportException catch (e, st) {
      developer.log('Export Error', error: e, stackTrace: st);
      exportError = e;
    } on Object catch (e, st) {
      developer.log('Export Error', error: e, stackTrace: st);
      exportError = e;
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
      // Make sure the overlay never lingers, even on success-then-share-fail.
      overlayCtrl.dismiss();
    }

    if (!context.mounted) {
      return;
    }
    if (userMessage != null) {
      _showSnackBarMessage(messenger, userMessage);
      return;
    }
    if (exportError == null) {
      return;
    }
    if (exportError is _PdfExportException) {
      unawaited(
        DaftarErrorSheet.show(
          context,
          content: _pdfExportErrorContent(l10n, exportError),
        ),
      );
      return;
    }
    unawaited(AppBottomSheet.showError(context, error: exportError));
  }

  LocalizedErrorContent _pdfExportErrorContent(
    AppLocalizations l10n,
    _PdfExportException error,
  ) {
    final message = switch (error.kind) {
      _PdfExportPhase.fetch => l10n.pdfFetchFailed,
      _PdfExportPhase.render => l10n.pdfRenderFailed,
      _PdfExportPhase.save => l10n.pdfSaveFailed,
      _PdfExportPhase.share => l10n.pdfShareFailed,
      _PdfExportPhase.timeout => l10n.pdfTimeout,
    };

    return LocalizedErrorContent(
      title: l10n.errorExportFailedTitle,
      message: message,
    );
  }

  List<Transaction> _transactionsInStatementRange(
    List<Transaction> transactions,
    DateTimeRange range,
  ) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );
    return transactions.where((t) {
      final local = t.transactionDate.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList(growable: false);
  }

  String _formatStatementPeriodLine(
    BuildContext context,
    AppLocalizations l10n,
    DateTimeRange range,
  ) {
    final fmt = DateFormat.yMd(AppConstants.numeralLocale);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );
    return '${l10n.statementPeriodLabel}: ${fmt.format(start)} – ${fmt.format(end)}';
  }

  void _showSnackBarMessage(ScaffoldMessengerState messenger, String message) {
    final colors = Theme.of(messenger.context).colorScheme;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFF171717),
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.error,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Returns the localized date group label for [date].
  ///
  /// Groups:
  /// - Today → l10n.today
  /// - Yesterday → l10n.yesterday
  /// - Within the last 7 days → l10n.thisWeek
  /// - Otherwise → month/year via `DateFormat.yMMMM('en_US')` (Latin numerals)
  String _getRelativeDateGroup(
    DateTime date,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txDate).inDays;

    if (diff == 0) return l10n.today;
    if (diff == 1) return l10n.yesterday;
    if (diff < 7) return l10n.thisWeek;

    return DateFormat.yMMMM(AppConstants.numeralLocale).format(date);
  }

  void _showTransactionUndoSnackBar({
    required BuildContext context,
    required Transaction transaction,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    final snackBar = SnackBar(
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: const Color(0xFF171717),
      content: Row(
        children: [
          const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Text(
              l10n.transactionDeleted,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: l10n.undo,
        textColor: colors.primary,
        onPressed: () {
          messenger.hideCurrentSnackBar();
          unawaited(
            ref
                .read(transactionControllerProvider.notifier)
                .restoreTransaction(transaction.id)
                .then((result) {
                  result.fold(
                    (_) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context)
                        ..removeCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsetsDirectional.fromSTEB(
                              16,
                              0,
                              16,
                              24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: const Color(0xFF171717),
                            content: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(
                                  width: AppDimensions.spacingMd,
                                ),
                                Expanded(
                                  child: Text(
                                    l10n.loadingError,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                    },
                    (_) {
                      unawaited(HapticService.undoTapped());
                    },
                  );
                }),
          );
        },
      ),
    );

    messenger.removeCurrentSnackBar();
    final controller = messenger.showSnackBar(snackBar);

    unawaited(
      Future<void>.delayed(const Duration(seconds: 5), () {
        try {
          controller.close();
        } on Object {
          // Ignore if already closed or the scaffold is gone.
        }
      }),
    );
  }
}

/// Full-width unified export CTA — share label centered, calendar on trailing edge.
///
/// The scaffold bottom slot passes a loose max height; the bar uses
/// [mainAxisSize: MainAxisSize.min] and a fixed [SizedBox] height.
class _StatementBottomBar extends StatefulWidget {
  const _StatementBottomBar({
    required this.label,
    required this.dateRangeLabel,
    required this.enabled,
    required this.isLoading,
    required this.isDark,
    required this.onPressed,
    required this.onExportDateRange,
  });

  final String label;
  final String dateRangeLabel;
  final bool enabled;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onPressed;
  final Future<void> Function() onExportDateRange;

  @override
  State<_StatementBottomBar> createState() => _StatementBottomBarState();
}

class _StatementBottomBarState extends State<_StatementBottomBar> {
  bool _pressed = false;

  static const double _barHeight = AppDimensions.comfortableTapTarget;

  bool get _isEnabled => widget.enabled && !widget.isLoading;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final glassFill = widget.isDark
        ? AppColors.glassFill
        : AppColors.glassFillLight;
    final fill = widget.isDark ? AppColors.surface2 : AppColors.surface1Light;
    final lapis = widget.isDark ? AppColors.lapis400 : AppColors.lapis500;
    final ink = widget.isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final border = widget.isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: glassFill,
              border: Border(
                top: BorderSide(
                  color: border,
                  width: AppDimensions.dividerThickness,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.pagePaddingH,
                  AppDimensions.spacingSm,
                  AppDimensions.pagePaddingH,
                  AppDimensions.spacingSm,
                ),
                child: AnimatedScale(
                  scale: _pressed && _isEnabled ? 0.98 : 1,
                  duration: AppDimensions.animationFast,
                  curve: Curves.easeOutCubic,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                      border: Border.all(
                        color: lapis,
                        width: AppDimensions.dividerThickness,
                      ),
                      boxShadow: _pressed && _isEnabled
                          ? AppGlows.ctaPressed
                          : AppGlows.ctaRest,
                    ),
                    child: SizedBox(
                      height: _barHeight,
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              enabled: _isEnabled,
                              label: widget.label,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: _isEnabled
                                    ? (_) => _setPressed(true)
                                    : null,
                                onTapUp: _isEnabled
                                    ? (_) => _setPressed(false)
                                    : null,
                                onTapCancel: _isEnabled
                                    ? () => _setPressed(false)
                                    : null,
                                onTap: _isEnabled
                                    ? () {
                                        unawaited(HapticService.buttonPress());
                                        widget.onPressed();
                                      }
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (widget.isLoading)
                                      SizedBox(
                                        width: AppDimensions.iconMedium,
                                        height: AppDimensions.iconMedium,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: ink,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.ios_share_rounded,
                                        size: AppDimensions.iconMedium,
                                        color: ink,
                                      ),
                                    const SizedBox(
                                      width: AppDimensions.spacingSm,
                                    ),
                                    Flexible(
                                      child: Text(
                                        widget.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.labelLarge
                                            .copyWith(
                                          color: ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: AppDimensions.dividerThickness,
                            height: 28,
                            color: border,
                          ),
                          Semantics(
                            button: true,
                            enabled: _isEnabled,
                            label: widget.dateRangeLabel,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: _isEnabled
                                  ? (_) => _setPressed(true)
                                  : null,
                              onTapUp: _isEnabled
                                  ? (_) => _setPressed(false)
                                  : null,
                              onTapCancel: _isEnabled
                                  ? () => _setPressed(false)
                                  : null,
                              onTap: _isEnabled
                                  ? () {
                                      unawaited(HapticService.selection());
                                      unawaited(widget.onExportDateRange());
                                    }
                                  : null,
                              child: SizedBox(
                                width: AppDimensions.minTapTarget,
                                height: _barHeight,
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  size: AppDimensions.iconMedium,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Elegant, minimal date-group header displayed above the first transaction
/// in each date section (Today, Yesterday, This Week, or Month Year).
///
/// A fixed-height [SizedBox] wraps the content so Flutter's scrolling engine
/// can cache the layout extent even when the header is optionally shown
/// inside the same even-index tile, preventing any scroll geometry drift.
class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({
    required this.label,
    required this.isDark,
  });

  final String label;
  final bool isDark;

  /// Fixed height keeps cached extents consistent across builds.
  static const double _height = AppDimensions.transactionDateGroupHeaderExtent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppDimensions.pagePaddingH,
          end: AppDimensions.pagePaddingH,
          top: 16,
          bottom: 8,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge.copyWith(
              color: isDark
                  ? AppColors.inkSecondary
                  : AppColors.inkSecondaryLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Monochrome extended FAB — lapis glow border, no solid fill.
class _LuxuryAddTransactionFab extends StatefulWidget {
  const _LuxuryAddTransactionFab({
    required this.isDark,
    required this.label,
    required this.onPressed,
  });

  final bool isDark;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_LuxuryAddTransactionFab> createState() => _LuxuryAddTransactionFabState();
}

class _LuxuryAddTransactionFabState extends State<_LuxuryAddTransactionFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.isDark ? AppColors.surface2 : AppColors.surface1Light;
    final lapis = widget.isDark ? AppColors.lapis400 : AppColors.lapis500;
    final inkColor = widget.isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.buttonPress());
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: AppDimensions.radiusMd,
                  cornerSmoothing: 0.6,
                ),
                side: BorderSide(
                  color: lapis,
                  width: AppDimensions.dividerThickness,
                ),
              ),
              shadows: _pressed ? AppGlows.ctaPressed : AppGlows.ctaRest,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppDimensions.spacingXl,
                vertical: AppDimensions.spacingMd,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: AppDimensions.iconMedium,
                    color: inkColor,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    widget.label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: inkColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _resolveNewTransactionCurrency({
  required Contact contact,
  required List<ContactBalance> balances,
  required String appDefaultCurrency,
  required bool isMultiCurrencyEnabled,
}) {
  if (!isMultiCurrencyEnabled) {
    final normalized = appDefaultCurrency.trim().toUpperCase();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return DbConstants.currencyYer;
  }

  final contactPreferredCurrency = contact.creditCurrency?.trim().toUpperCase();
  if (contactPreferredCurrency != null && contactPreferredCurrency.isNotEmpty) {
    return contactPreferredCurrency;
  }

  final mostUsedCurrency = _mostUsedBalanceCurrency(balances);
  if (mostUsedCurrency != null && mostUsedCurrency.isNotEmpty) {
    return mostUsedCurrency;
  }

  final normalizedAppDefault = appDefaultCurrency.trim().toUpperCase();
  if (normalizedAppDefault.isNotEmpty) {
    return normalizedAppDefault;
  }

  return DbConstants.currencyYer;
}

String? _mostUsedBalanceCurrency(List<ContactBalance> balances) {
  if (balances.isEmpty) {
    return null;
  }

  var selectedBalance = balances.first;
  var selectedActivity =
      selectedBalance.totalDebt + selectedBalance.totalPayment;

  for (final balance in balances.skip(1)) {
    final activity = balance.totalDebt + balance.totalPayment;
    if (activity > selectedActivity) {
      selectedBalance = balance;
      selectedActivity = activity;
    }
  }

  final normalizedCurrency = selectedBalance.currencyCode.trim().toUpperCase();
  return normalizedCurrency.isEmpty ? null : normalizedCurrency;
}

Future<void> _launchWhatsApp(
  BuildContext context,
  String? phone,
) async {
  final l10n = AppLocalizations.of(context)!;
  final launched = await WhatsAppUtil.openWhatsApp(phone: phone ?? '');

  if (!launched && context.mounted) {
    _showLaunchErrorSnackBar(context, l10n.whatsappLaunchError);
  }
}

Future<void> _launchCall(
  BuildContext context,
  String? phone,
) async {
  final l10n = AppLocalizations.of(context)!;
  final sanitizedPhone = WhatsAppUtil.sanitizePhone(phone ?? '');

  if (sanitizedPhone.isEmpty) {
    _showLaunchErrorSnackBar(context, l10n.callLaunchError);
    return;
  }

  final telUri = Uri.parse('tel:$sanitizedPhone');

  await _launchExternalUri(
    context,
    telUri,
    l10n.callLaunchError,
  );
}

Future<void> _launchExternalUri(
  BuildContext context,
  Uri uri,
  String errorMessage,
) async {
  try {
    final canLaunch = await canLaunchUrl(uri);
    final launched =
        canLaunch &&
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

    if (!launched && context.mounted) {
      _showLaunchErrorSnackBar(context, errorMessage);
    }
  } on Object {
    if (context.mounted) {
      _showLaunchErrorSnackBar(context, errorMessage);
    }
  }
}

void _showLaunchErrorSnackBar(BuildContext context, String message) {
  final colors = context.colorScheme;

  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: const Color(0xFF171717),
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

// =============================================================================
// Client Vault Hero — squircle glass card with Khazna Float elevation
// =============================================================================

class _ClientVaultHeroCard extends StatelessWidget {
  const _ClientVaultHeroCard({
    required this.contactId,
    required this.contactName,
    required this.phone,
    required this.avatarColorHex,
    required this.isDark,
    required this.callLabel,
    required this.whatsAppLabel,
    this.onCall,
    this.onWhatsApp,
  });

  final String contactId;
  final String contactName;
  final String? phone;
  final String avatarColorHex;
  final bool isDark;
  final String callLabel;
  final String whatsAppLabel;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final glassBorder = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final accent = _parseHexColor(
      avatarColorHex,
      fallback: colors.onSurfaceVariant,
    );
    final hasPhone = phone != null && phone!.trim().isNotEmpty;

    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusXl,
      cornerSmoothing: 0.6,
    );

    return ClipSmoothRect(
      radius: squircleRadius,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: glassFill,
          shape: SmoothRectangleBorder(
            borderRadius: squircleRadius,
            side: BorderSide(
              color: glassBorder,
              width: AppDimensions.dividerThickness,
            ),
          ),
        ),
        child: Stack(
              children: [
                if (isDark)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: ColoredBox(color: AppColors.innerTopHighlight),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.spacingXl,
                    AppDimensions.spacingXl,
                    AppDimensions.spacingXl,
                    AppDimensions.spacingLg,
                  ),
                  child: Row(
                    children: [
                      _ContactVaultAvatar(
                        name: contactName,
                        tint: accent,
                        isDark: isDark,
                      ),
                      const SizedBox(width: AppDimensions.spacingLg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Hero(
                              tag: 'contact_name_hero_$contactId',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  contactName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.headlineMedium.copyWith(
                                    color: inkPrimary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            if (hasPhone) ...[
                              const SizedBox(
                                height: AppDimensions.spacingSm,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      phone!,
                                      textDirection: ui.TextDirection.ltr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: inkSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: AppDimensions.spacingSm,
                                  ),
                                  _HeroContactAction(
                                    isDark: isDark,
                                    semanticsLabel: callLabel,
                                    icon: Icons.call_rounded,
                                    onPressed: onCall,
                                  ),
                                  const SizedBox(
                                    width: AppDimensions.spacingXs,
                                  ),
                                  _HeroContactAction(
                                    isDark: isDark,
                                    semanticsLabel: whatsAppLabel,
                                    icon: Icons.chat_rounded,
                                    iconTint: const Color(0xFF25D366),
                                    onPressed: onWhatsApp,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _ContactVaultAvatar extends StatelessWidget {
  const _ContactVaultAvatar({
    required this.name,
    required this.tint,
    required this.isDark,
  });

  final String name;
  final Color tint;
  final bool isDark;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusLg + 4,
      cornerSmoothing: 0.65,
    );

    return ClipSmoothRect(
      radius: squircleRadius,
      child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                tint.withValues(alpha: isDark ? 0.95 : 0.88),
                Color.alphaBlend(
                  tint.withValues(alpha: isDark ? 0.55 : 0.45),
                  isDark ? AppColors.surface3 : AppColors.surface2Light,
                ),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _buildInitials(name),
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    );
  }
}

class _HeroContactAction extends StatefulWidget {
  const _HeroContactAction({
    required this.isDark,
    required this.semanticsLabel,
    required this.icon,
    required this.onPressed,
    this.iconTint,
  });

  final bool isDark;
  final String semanticsLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconTint;

  @override
  State<_HeroContactAction> createState() => _HeroContactActionState();
}

class _HeroContactActionState extends State<_HeroContactAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final fill = widget.isDark ? AppColors.surface2 : AppColors.surface1Light;
    final border = widget.isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final iconColor = enabled
        ? (widget.iconTint ??
              (widget.isDark
                  ? AppColors.inkPrimary
                  : AppColors.inkPrimaryLight))
        : (widget.isDark ? AppColors.inkMuted : AppColors.inkMutedLight);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled
            ? () {
                unawaited(HapticService.selection());
                widget.onPressed?.call();
              }
            : null,
        child: DaftarTapTarget(
          child: AnimatedScale(
            scale: _pressed && enabled ? 0.98 : 1,
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: border,
                    width: AppDimensions.dividerThickness,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  size: AppDimensions.iconSmall + 2,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Toolbar chrome — squircle back + edit icon
// =============================================================================

class _LuxuryBackButton extends StatefulWidget {
  const _LuxuryBackButton({
    required this.isDark,
    required this.onPressed,
  });

  final bool isDark;
  final VoidCallback onPressed;

  @override
  State<_LuxuryBackButton> createState() => _LuxuryBackButtonState();
}

class _LuxuryBackButtonState extends State<_LuxuryBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.isDark ? AppColors.surface3 : AppColors.surface1Light;
    final border = widget.isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final ink = widget.isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.selection());
          widget.onPressed();
        },
        child: DaftarTapTarget(
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1,
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            child: Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                color: fill,
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: AppDimensions.radiusSm + 2,
                    cornerSmoothing: 0.6,
                  ),
                  side: BorderSide(
                    color: border,
                    width: AppDimensions.dividerThickness,
                  ),
                ),
                shadows: widget.isDark
                    ? AppGlows.khazaFloat
                    : AppGlows.shadowSoft,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: AppDimensions.iconMedium,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxuryToolbarIcon extends StatefulWidget {
  const _LuxuryToolbarIcon({
    required this.isDark,
    required this.semanticsLabel,
    required this.icon,
    required this.onPressed,
  });

  final bool isDark;
  final String semanticsLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_LuxuryToolbarIcon> createState() => _LuxuryToolbarIconState();
}

class _LuxuryToolbarIconState extends State<_LuxuryToolbarIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.isDark ? AppColors.surface3 : AppColors.surface1Light;
    final border = widget.isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final ink = widget.isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.selection());
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: Container(
            width: AppDimensions.minTapTarget,
            height: AppDimensions.minTapTarget,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: border,
                width: AppDimensions.dividerThickness,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: AppDimensions.iconMedium,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Internal export-failure taxonomy — drives differentiated error messages.
// ============================================================================

enum _PdfExportPhase { fetch, render, save, share, timeout }

class _ExportFlowFailure implements Exception {
  _ExportFlowFailure(this.failure);

  final Failure failure;
}

class _PdfExportException implements Exception {
  _PdfExportException(this.kind, this.detail);

  factory _PdfExportException.fetch(String detail) =>
      _PdfExportException(_PdfExportPhase.fetch, detail);
  factory _PdfExportException.render(String detail) =>
      _PdfExportException(_PdfExportPhase.render, detail);
  factory _PdfExportException.save(String detail) =>
      _PdfExportException(_PdfExportPhase.save, detail);
  factory _PdfExportException.share(String detail) =>
      _PdfExportException(_PdfExportPhase.share, detail);
  factory _PdfExportException.timeout() =>
      _PdfExportException(_PdfExportPhase.timeout, 'timeout');

  final _PdfExportPhase kind;
  final String detail;

  @override
  String toString() => '_PdfExportException(${kind.name}: $detail)';
}

class _ContactTransactionListSliver extends ConsumerWidget {
  const _ContactTransactionListSliver({
    required this.contactId,
    required this.screenContext,
    required this.transactions,
    required this.l10n,
    required this.isDark,
    required this.currencyCode,
    required this.contactName,
    required this.swipeEnabled,
    required this.isReadOnly,
    required this.getRelativeDateGroup,
    required this.onTransactionDeleted,
  });

  final String contactId;
  final BuildContext screenContext;
  final List<Transaction> transactions;
  final AppLocalizations l10n;
  final bool isDark;
  final String currencyCode;
  final String contactName;
  final bool swipeEnabled;
  final bool isReadOnly;
  final String Function(DateTime date, AppLocalizations l10n) getRelativeDateGroup;
  final void Function(Transaction transaction) onTransactionDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionIndexById = <String, int>{
      for (var i = 0; i < transactions.length; i++) transactions[i].id: i,
    };
    final editCallbacks = <String, Future<void> Function()>{};
    final deleteCallbacks = <String, VoidCallback>{};
    final dismissCallbacks = <String, void Function(Transaction)>{};

    Future<void> Function()? editFor(Transaction transaction) {
      if (isReadOnly) {
        return null;
      }
      return editCallbacks.putIfAbsent(transaction.id, () {
        return () async {
          await showAddTransactionDialog(
            screenContext,
            contactId: contactId,
            contactName: contactName,
            defaultCurrency: currencyCode,
            existingTransaction: transaction,
          );
        };
      });
    }

    VoidCallback? deleteFor(Transaction transaction) {
      if (isReadOnly) {
        return null;
      }
      return deleteCallbacks.putIfAbsent(transaction.id, () {
        return () {
          unawaited(
            ref
                .read(transactionControllerProvider.notifier)
                .deleteTransaction(transaction.id),
          );
          onTransactionDeleted(transaction);
        };
      });
    }

    void Function(Transaction)? dismissFor(Transaction transaction) {
      if (isReadOnly) {
        return null;
      }
      return dismissCallbacks.putIfAbsent(transaction.id, () {
        return (Transaction txn) {
          unawaited(
            ref
                .read(transactionControllerProvider.notifier)
                .deleteTransaction(txn.id),
          );
          onTransactionDeleted(txn);
        };
      });
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rawIndex) {
          if (rawIndex.isOdd) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.pagePaddingH,
              ),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
              ),
            );
          }

          final index = rawIndex ~/ 2;
          final transaction = transactions[index];
          final currentGroup = getRelativeDateGroup(
            transaction.createdAt,
            l10n,
          );
          final showHeader =
              index == 0 ||
              getRelativeDateGroup(
                    transactions[index - 1].createdAt,
                    l10n,
                  ) !=
                  currentGroup;

          final tile = TransactionListTile(
            transaction: transaction,
            swipeEnabled: swipeEnabled,
            onEdit: editFor(transaction),
            onDelete: deleteFor(transaction),
            onDismissed: dismissFor(transaction),
            onTap: editFor(transaction),
          );

          return SizedBox(
            key: ValueKey<String>(transaction.id),
            height: showHeader
                ? AppDimensions.transactionListTileStrideExtent
                : AppDimensions.transactionListTileExtent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  _DateGroupHeader(label: currentGroup, isDark: isDark),
                Expanded(child: tile),
              ],
            ),
          );
        },
        childCount: transactions.isEmpty ? 0 : transactions.length * 2 - 1,
        findChildIndexCallback: (key) {
          if (key is ValueKey<String>) {
            final index = transactionIndexById[key.value];
            if (index != null) {
              return index * 2;
            }
          }
          return null;
        },
        addRepaintBoundaries: false,
      ),
    );
  }
}

String _buildInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }

  if (parts.length == 1) {
    final token = parts.first;
    return token.isNotEmpty ? token.substring(0, 1).toUpperCase() : '?';
  }

  final first = parts.first.substring(0, 1);
  final last = parts.last.substring(0, 1);
  return (first + last).toUpperCase();
}

Color _parseHexColor(String value, {required Color fallback}) {
  final normalized = value.trim().toLowerCase().replaceFirst(
    RegExp('^(#|0x)'),
    '',
  );

  try {
    if (normalized.length == 3) {
      final expanded = normalized
          .split('')
          .map((digit) => '$digit$digit')
          .join();
      return Color(int.parse('ff$expanded', radix: 16));
    }

    if (normalized.length == 6) {
      return Color(int.parse('ff$normalized', radix: 16));
    }

    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
  } on Object {
    return fallback;
  }

  return fallback;
}

bool _hasPhoneNumber(String? phone) {
  return phone != null && phone.trim().isNotEmpty;
}
