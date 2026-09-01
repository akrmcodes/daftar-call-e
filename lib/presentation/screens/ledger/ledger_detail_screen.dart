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
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/localized_error_content.dart';
import 'package:daftar/core/utils/pdf_ledger_summary.dart';
import 'package:daftar/core/utils/pdf_storage_service.dart';
import 'package:daftar/core/utils/statement_share.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/value_objects/contact_with_summary.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/providers/permissions_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:daftar/presentation/providers/workspace_limit_providers.dart';
import 'package:daftar/presentation/screens/contact/widgets/archived_ledger_read_only_banner.dart';
import 'package:daftar/presentation/screens/contact/widgets/export_progress_overlay.dart';
import 'package:daftar/presentation/screens/contact/widgets/show_edit_contact_sheet.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card.dart';
import 'package:daftar/presentation/screens/ledger/ledger_contact_list_pipeline.dart';
import 'package:daftar/presentation/screens/ledger/widgets/add_contact_sheet.dart';
import 'package:daftar/presentation/screens/ledger/widgets/contact_list_tile.dart';
import 'package:daftar/presentation/screens/ledger/widgets/sort_filter_sheet.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/contact_delete_confirm_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_sliver_refresh.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:daftar/presentation/shared/widgets/empty_state.dart';
import 'package:daftar/presentation/shared/widgets/search_bar.dart'
    as daftar_widgets;
import 'package:daftar/presentation/shared/widgets/skeleton_contact_list.dart';
import 'package:daftar/presentation/widgets/premium/premium_upgrade_banner.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

// =============================================================================
// Sort & Filter constants
// =============================================================================

const String _sortModeName = 'name';

/// Balance polarity filter modes.
///
/// The math is:
///   - `all`:     no filter — show every contact
///   - `debt`:    netBalance < 0 — they owe us (عليه)
///   - `credit`:  netBalance > 0 — we owe them (له)
///   - `settled`: netBalance == 0 — fully settled (مُسدّد)
const String _filterAll = 'all';
const String _filterDebt = 'debt';
const String _filterCredit = 'credit';
const String _filterSettled = 'settled';

/// Ledger Detail Screen — Private-banking-grade accounts portfolio view.
///
/// **State management architecture (search + filter + sort):**
///
/// The screen maintains three pieces of local UI state:
///   1. `_searchQuery` — the current normalized search text (debounced 300ms)
///   2. `_currentFilter` — balance polarity filter (all/debt/credit/settled)
///   3. `_currentSortMode` — sort order (name/balance/recent)
///
/// These three states compose a **pipeline** that runs on every rebuild:
///   contacts (from Drift stream)
///     → search filter (name contains normalized query)
///     → balance polarity filter (debt/credit/settled)
///     → sort (name/balance/recent)
///     → rendered list
///
/// The `_ContactTileRow` widget receives pre-resolved summary data from
/// [contactSummariesByLedgerProvider] — zero per-tile provider watches.
class LedgerDetailScreen extends ConsumerStatefulWidget {
  const LedgerDetailScreen({required this.ledgerId, super.key});

  final String ledgerId;

  @override
  ConsumerState<LedgerDetailScreen> createState() => _LedgerDetailScreenState();
}

class _LedgerDetailScreenState extends ConsumerState<LedgerDetailScreen> {
  String _currentSortMode = _sortModeName;
  String _currentFilter = _filterAll;
  String _searchQuery = '';

  Object? _pipelineCacheKey;
  List<LedgerContactRow>? _cachedSortedRows;
  final Set<String> _animatedContactIds = {};

  bool _isExporting = false;

  Future<void> _onRefresh() => daftarRefreshWithPerceivedDelay(() async {
        ref
          ..invalidate(contactSummariesByLedgerProvider(widget.ledgerId))
          ..invalidate(contactsProvider(widget.ledgerId));
        await ref.read(contactSummariesByLedgerProvider(widget.ledgerId).future);
      });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    // ── Derive ledger name from the reactive ledgers stream ──────
    final asyncLedger = ref.watch(ledgerByIdProvider(widget.ledgerId));
    final ledgersList = ref.watch(ledgersProvider);
    final ledgerName = asyncLedger.when(
      data: (result) => result.fold(
        (_) => l10n.myLedgers,
        (ledger) => ledger.name,
      ),
      loading: () {
        final fromList = ledgersList.asData?.value
            .where((ledger) => ledger.id == widget.ledgerId)
            .map((ledger) => ledger.name)
            .firstOrNull;
        return fromList ?? l10n.myLedgers;
      },
      error: (_, _) => l10n.myLedgers,
    );
    final sourceLedger = asyncLedger.asData?.value.getRight().toNullable() ??
        ledgersList.asData?.value
            .where((ledger) => ledger.id == widget.ledgerId)
            .firstOrNull;
    final isReadOnly = ref.watch(isLedgerReadOnlyProvider(widget.ledgerId)).value ??
        sourceLedger?.isUserArchived ??
        false;
    final canEditContacts =
        ref.watch(canPerformProvider(WorkspacePermission.editContactsAndLedgers)).value ??
            true;
    final swipeEnabled = !isReadOnly &&
        (ref.watch(appSettingsProvider).asData?.value.isSwipeToDeleteEnabled ??
            false);

    final asyncSummaries =
        ref.watch(contactSummariesByLedgerProvider(widget.ledgerId));
    final contactsById = <String, Contact>{
      for (final contact
          in ref.watch(contactsProvider(widget.ledgerId)).value ??
              const <Contact>[])
        contact.id: contact,
    };
    final isContactsEmpty =
        asyncSummaries.hasValue && (asyncSummaries.asData?.value.isEmpty ?? false);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: isReadOnly ||
              !canEditContacts ||
              isContactsEmpty
          ? null
          : _AddContactFab(
              onPressed: _showAddContactSheet,
              label: l10n.addContact,
              isDark: isDark,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          DaftarSliverRefreshControl(onRefresh: _onRefresh),
          // ── App bar ──
          SliverAppBar.medium(
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.scaffoldBackgroundColor,
            foregroundColor: colors.onSurface,
            automaticallyImplyLeading: false,
            scrolledUnderElevation: 0,
            leadingWidth: 72,
            leading: _ElegantBackButton(
              isDark: isDark,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.home);
                }
              },
            ),
            title: Text(
              ledgerName,
              style: AppTextStyles.titleLarge.copyWith(
                color: isDark
                    ? AppColors.inkPrimary
                    : AppColors.inkPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                tooltip: l10n.exportLedgerSummary,
                onPressed: _isExporting
                    ? null
                    : () => unawaited(
                          _exportLedgerSummary(
                            context: context,
                            ledgerName: ledgerName,
                          ),
                        ),
                icon: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: isDark
                      ? AppColors.inkSecondary
                      : AppColors.inkSecondaryLight,
                ),
              ),
            ],
          ),

          if (isReadOnly)
            ArchivedLedgerReadOnlyBanner(
              title: l10n.ledgerArchivedReadOnlyTitle,
              subtitle: l10n.ledgerArchivedReadOnlySubtitle,
            ),

          // ── Balance Card ──
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              AppDimensions.spacingLg,
              AppDimensions.pagePaddingH,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: BalanceCard(ledgerId: widget.ledgerId),
            ),
          ),

          // ── Pinned search + filter toolbar ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _LedgerDetailHeaderDelegate(
              isDark: isDark,
              searchHintText: l10n.searchContacts,
              sortTooltip: l10n.sort,
              onSortPressed: _handleSortPressed,
              onSearchChanged: _handleSearchChanged,
              currentFilter: _currentFilter,
              onFilterChanged: _handleFilterChanged,
            ),
          ),

          // ── Contact list: single summary stream ──────────
          ...asyncSummaries.when(
            loading: () => [
              const SliverPadding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: AppDimensions.pagePaddingH,
                  vertical: AppDimensions.spacingLg,
                ),
                sliver: SliverToBoxAdapter(
                  child: SkeletonContactList(),
                ),
              ),
            ],
            error: (error, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingXl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color:
                                (isDark ? AppColors.debt : AppColors.debtLight)
                                    .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: AppDimensions.iconLarge - 16,
                            color: isDark
                                ? AppColors.debt
                                : AppColors.debtLight,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        Text(
                          l10n.loadingError,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.inkSecondary
                                : AppColors.inkSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            data: (summaries) {
              if (summaries.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: l10n.noContactsYet,
                      subtitle: l10n.noContactsSubtitle,
                      ctaLabel: l10n.addContact,
                      ctaIcon: Icons.person_add_rounded,
                      onCtaPressed: isReadOnly || !canEditContacts
                          ? null
                          : _showAddContactSheet,
                    ),
                  ),
                ];
              }

              final sorted = _sortedRowsFor(summaries, contactsById);
              if (sorted.isEmpty) {
                final isSearching = _searchQuery.isNotEmpty;
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(
                          AppDimensions.spacingXl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSearching
                                  ? Icons.search_off_rounded
                                  : Icons.filter_list_off_rounded,
                              size: AppDimensions.iconLarge,
                              color: isDark
                                  ? AppColors.inkMuted
                                  : AppColors.inkMutedLight,
                            ),
                            const SizedBox(
                              height: AppDimensions.spacingLg,
                            ),
                            Text(
                              isSearching
                                  ? l10n.noSearchResults
                                  : l10n.noFilterResults,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isDark
                                    ? AppColors.inkSecondary
                                    : AppColors.inkSecondaryLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              }

              return [
                SliverPadding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: PremiumUpgradeBanner(
                      resource: WorkspaceLimitResource.contacts,
                      onUpgradeTap: () =>
                          context.pushNamed(RouteNames.activation),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.pagePaddingH,
                    AppDimensions.spacingMd,
                    AppDimensions.pagePaddingH,
                    // Extra bottom for FAB clearance + safe area
                    AppDimensions.spacing6xl + AppDimensions.spacing3xl,
                  ),
                  sliver: SliverFixedExtentList(
                    itemExtent: AppDimensions.contactListTileExtent,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final row = sorted[index];

                        return Align(
                          key: ValueKey<String>('contact-${row.contactId}'),
                          alignment: AlignmentDirectional.topStart,
                          child: _ContactTileRow(
                              row: row,
                              index: index,
                              animatedContactIds: _animatedContactIds,
                              onTap: () {
                                unawaited(
                                  context.pushNamed(
                                    RouteNames.contactDetail,
                                    pathParameters: {
                                      RouteNames.contactIdParam: row.contactId,
                                    },
                                  ),
                                );
                              },
                              swipeEnabled: swipeEnabled,
                              onEdit: isReadOnly
                                  ? null
                                  : () => unawaited(
                                        showEditContactSheet(
                                          context,
                                          contact: row.contact,
                                        ),
                                      ),
                              onDelete: isReadOnly
                                  ? null
                                  : () => unawaited(
                                        _requestDeleteContact(
                                          row.contact,
                                          row.transactionCount,
                                        ),
                                      ),
                              confirmDelete: () => _confirmDeleteContact(
                                row.contact,
                                row.transactionCount,
                              ),
                              onDismissed: () =>
                                  _performContactDelete(row.contact),
                            ),
                        );
                      },
                      childCount: sorted.length,
                      findChildIndexCallback: (key) {
                        if (key is! ValueKey<String>) {
                          return null;
                        }
                        final id = key.value;
                        if (!id.startsWith('contact-')) {
                          return null;
                        }
                        final contactId = id.substring('contact-'.length);
                        final index = sorted.indexWhere(
                          (row) => row.contactId == contactId,
                        );
                        return index >= 0 ? index : null;
                      },
                    ),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // State mutation callbacks
  // ═══════════════════════════════════════════════════════════════════════════

  /// Called by the SearchBar's debounced onChanged. Drives the search pipeline.
  void _handleSearchChanged(String query) {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) {
      return;
    }

    setState(() => _searchQuery = trimmed);
  }

  /// Called when a filter chip is tapped.
  void _handleFilterChanged(String filter) {
    if (filter == _currentFilter) {
      return;
    }

    unawaited(HapticService.selection());
    setState(() => _currentFilter = filter);
  }

  List<LedgerContactRow> _sortedRowsFor(
    List<ContactWithSummary> summaries,
    Map<String, Contact> contactsById,
  ) {
    final cacheKey = Object.hash(
      Object.hashAll(summaries),
      Object.hashAll(
        contactsById.entries.map(
          (entry) => Object.hash(entry.key, entry.value.updatedAt),
        ),
      ),
      _searchQuery,
      _currentFilter,
      _currentSortMode,
    );

    if (_pipelineCacheKey == cacheKey && _cachedSortedRows != null) {
      return _cachedSortedRows!;
    }

    _pipelineCacheKey = cacheKey;
    _cachedSortedRows = LedgerContactListPipeline(
      summaries: summaries,
      contactsById: contactsById,
      searchQuery: _searchQuery,
      currentFilter: _currentFilter,
      currentSortMode: _currentSortMode,
    ).compute();
    return _cachedSortedRows!;
  }

  Future<void> _showAddContactSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;

    await AppBottomSheet.show<Contact>(
      context,
      title: l10n.addContact,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.lapis400.withValues(
            alpha: isDark ? 0.16 : 0.12,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.account_circle_rounded,
          color: isDark ? AppColors.lapis400 : AppColors.lapis500,
          size: AppDimensions.iconMedium,
        ),
      ),
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: AddContactSheet(ledgerId: widget.ledgerId),
    );
  }

  void _handleSortPressed() {
    unawaited(
      SortFilterSheet.show(
        context,
        currentSortOption: _currentSortMode,
        onSortChanged: (newSort) {
          if (!mounted || newSort == _currentSortMode) {
            return;
          }

          setState(() {
            _currentSortMode = newSort;
          });
        },
      ),
    );
  }

  Future<bool> _confirmDeleteContact(
    Contact contact,
    int transactionsCount,
  ) async {
    return ContactDeleteConfirmSheet.show(
      context,
      contactName: contact.name,
      transactionsCount: transactionsCount,
    );
  }

  Future<void> _requestDeleteContact(
    Contact contact,
    int transactionsCount,
  ) async {
    final confirmed = await _confirmDeleteContact(contact, transactionsCount);
    if (!confirmed || !mounted) {
      return;
    }
    _performContactDelete(contact);
  }

  void _performContactDelete(Contact contact) {
    unawaited(
      ref.read(contactControllerProvider.notifier).deleteContact(contact.id),
    );
    _showUndoDeleteSnackBar(contact: contact);
  }

  void _showUndoDeleteSnackBar({required Contact contact}) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);

    final snackBar = SnackBar(
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      shape: SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius(
          cornerRadius: AppDimensions.radiusMd,
          cornerSmoothing: 0.6,
        ),
      ),
      backgroundColor: isDark ? AppColors.surface3 : const Color(0xFF171717),
      content: Row(
        children: [
          Icon(
            Icons.delete_outline_rounded,
            color: isDark ? AppColors.inkPrimary : Colors.white,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Text(
              l10n.contactDeleted,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.inkPrimary : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: l10n.undo,
        textColor: isDark ? AppColors.lapis400 : AppColors.lapis300,
        onPressed: () {
          messenger.hideCurrentSnackBar();
          unawaited(
            ref
                .read(contactControllerProvider.notifier)
                .restoreContact(contact.id)
                .then((result) {
              result.fold(
                (_) {},
                (_) => unawaited(HapticService.undoTapped()),
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

  /// Sorts a copy of the contacts list based on [_currentSortMode].
  Future<void> _exportLedgerSummary({
    required BuildContext context,
    required String ledgerName,
  }) async {
    if (_isExporting) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;

    setState(() => _isExporting = true);

    final overlayCtrl = ExportProgressOverlay.show(
      context,
      title: l10n.exportLedgerSummary,
    );

    Object? exportError;
    try {
      overlayCtrl.update(0.05, l10n.pdfPreparingData);

      final exportData = await ref
          .read(prepareLedgerSummaryExportUseCaseProvider)
          .execute(widget.ledgerId);

      final data = exportData.fold(
        (failure) => throw _LedgerExportFlowFailure(failure),
        (value) => value,
      );

      if (!context.mounted) {
        overlayCtrl.dismiss();
        return;
      }

      final effectiveProfile = await ref
          .read(resolvePdfMerchantProfileUseCaseProvider)
          .execute();

      final Uint8List pdfBytes;
      try {
        pdfBytes = await LedgerSummaryPdfGenerator.generate(
          data: data,
          isRtl: isRtl,
          applicationName: l10n.appTitle,
          labelSummaryTitle: l10n.ledgerSummaryReport,
          labelLedgerName: l10n.ledgerName,
          labelGeneratedOn: l10n.generatedOn,
          labelTotalLedgerBalance: l10n.totalLedgerBalance,
          labelTotalDebt: l10n.totalDebt,
          labelTotalPayment: l10n.totalPayment,
          labelNetBalance: l10n.netBalance,
          labelRowNumber: l10n.rowNumber,
          labelName: l10n.name,
          labelPhone: l10n.phoneNumber,
          labelCurrency: l10n.currency,
          labelPage: l10n.page,
          msgPreparing: l10n.pdfPreparingData,
          msgGrouping: l10n.pdfGroupingAccounts,
          msgBuilding: l10n.pdfBuildingLayout,
          msgRendering: l10n.pdfRendering,
          onProgress: overlayCtrl.update,
          merchantProfile: effectiveProfile,
        );
      } on TimeoutException {
        throw _LedgerPdfExportException.timeout();
      } on Object {
        throw _LedgerPdfExportException.render('');
      }

      final hasSpace = await ref.read(storageServiceProvider).hasEnoughSpace();
      if (!hasSpace) {
        throw _LedgerExportFlowFailure(const StorageFullFailure());
      }

      final File savedFile;
      try {
        overlayCtrl.update(0.95, l10n.pdfSaving);
        savedFile = await PdfStorageService.saveLedgerSummary(
          pdfBytes: pdfBytes,
          ledgerName: ledgerName,
        );
      } on Object {
        throw _LedgerPdfExportException.save('');
      }

      overlayCtrl.complete(l10n.pdfComplete);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      overlayCtrl.dismiss();

      try {
        await StatementShare.shareStatementPdf(
          file: XFile(savedFile.path),
          shareTitle: l10n.shareLedgerSummary,
          shareSubject: l10n.ledgerSummaryShareSubject(ledgerName),
        );
      } on Object {
        throw _LedgerPdfExportException.share('');
      }
    } on _LedgerExportFlowFailure catch (e, st) {
      developer.log('Ledger summary export', error: e.failure, stackTrace: st);
      exportError = e.failure;
    } on _LedgerPdfExportException catch (e, st) {
      developer.log('Ledger summary export', error: e, stackTrace: st);
      exportError = e;
    } on Object catch (e, st) {
      developer.log('Ledger summary export', error: e, stackTrace: st);
      exportError = e;
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
      overlayCtrl.dismiss();
    }

    if (!context.mounted || exportError == null) {
      return;
    }

    if (exportError is _LedgerPdfExportException) {
      unawaited(
        DaftarErrorSheet.show(
          context,
          content: _ledgerPdfExportErrorContent(l10n, exportError),
        ),
      );
      return;
    }

    unawaited(AppBottomSheet.showError(context, error: exportError));
  }

  LocalizedErrorContent _ledgerPdfExportErrorContent(
    AppLocalizations l10n,
    _LedgerPdfExportException error,
  ) {
    final message = switch (error.kind) {
      _LedgerPdfExportPhase.fetch => l10n.pdfFetchFailed,
      _LedgerPdfExportPhase.render => l10n.pdfRenderFailed,
      _LedgerPdfExportPhase.save => l10n.pdfSaveFailed,
      _LedgerPdfExportPhase.share => l10n.pdfShareFailed,
      _LedgerPdfExportPhase.timeout => l10n.pdfTimeout,
    };

    return LocalizedErrorContent(
      title: l10n.errorExportFailedTitle,
      message: message,
    );
  }
}

// =============================================================================
// _ContactTileRow — pure data-pass-through tile (no provider watches)
// =============================================================================

class _ContactTileRow extends StatefulWidget {
  const _ContactTileRow({
    required this.row,
    required this.index,
    required this.animatedContactIds,
    required this.onTap,
    required this.onDismissed,
    required this.swipeEnabled,
    this.onEdit,
    this.onDelete,
    this.confirmDelete,
  });

  final LedgerContactRow row;
  final int index;
  final Set<String> animatedContactIds;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final bool swipeEnabled;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Future<bool> Function()? confirmDelete;

  @override
  State<_ContactTileRow> createState() => _ContactTileRowState();
}

class _ContactTileRowState extends State<_ContactTileRow> {
  late final bool _shouldAnimate;

  @override
  void initState() {
    super.initState();
    _shouldAnimate = !widget.animatedContactIds.contains(widget.row.contactId) &&
        widget.index < 8;
    if (_shouldAnimate) {
      widget.animatedContactIds.add(widget.row.contactId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deferAnimations = MediaQuery.disableAnimationsOf(context);
    final staggerDelay = _shouldAnimate && !deferAnimations
        ? Duration(milliseconds: 40 * widget.index)
        : Duration.zero;

    final tile = ContactListTile(
      contact: widget.row.contact,
      netBalance: widget.row.netBalance,
      currencyCode: widget.row.currencyCode,
      transactionsCount: widget.row.transactionCount,
      onTap: widget.onTap,
      onDismissed: widget.onDismissed,
      swipeEnabled: widget.swipeEnabled,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
      confirmDelete: widget.confirmDelete,
      enableHero: false,
    );

    if (!_shouldAnimate || deferAnimations) {
      return tile;
    }

    return tile
        .animate()
        .fadeIn(
          delay: staggerDelay,
          duration: AppDimensions.animationMedium,
          curve: AppMotion.curveEnter,
        )
        .slideY(
          delay: staggerDelay,
          begin: 0.06,
          end: 0,
          duration: AppDimensions.animationMedium,
          curve: AppMotion.curveEnter,
        );
  }
}

// =============================================================================
// _ElegantBackButton — frosted circular back navigation
// =============================================================================

class _ElegantBackButton extends StatefulWidget {
  const _ElegantBackButton({
    required this.isDark,
    required this.onPressed,
  });

  final bool isDark;
  final VoidCallback onPressed;

  @override
  State<_ElegantBackButton> createState() => _ElegantBackButtonState();
}

class _ElegantBackButtonState extends State<_ElegantBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.isDark ? AppColors.surface3 : AppColors.surface1Light;
    final border = widget.isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.light());
          widget.onPressed();
        },
        child: DaftarTapTarget(
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            child: RepaintBoundary(
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
                  color: widget.isDark
                      ? AppColors.inkPrimary
                      : AppColors.inkPrimaryLight,
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
// _LedgerDetailHeaderDelegate — pinned search + filter + sort toolbar
// =============================================================================

class _LedgerDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _LedgerDetailHeaderDelegate({
    required this.isDark,
    required this.searchHintText,
    required this.sortTooltip,
    required this.onSortPressed,
    required this.onSearchChanged,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  final bool isDark;
  final String searchHintText;
  final String sortTooltip;
  final VoidCallback onSortPressed;
  final ValueChanged<String> onSearchChanged;
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;

  // Outer padding: 8 top
  // Search row: 56 (comfortableTapTarget) + 12 top padding = 68
  // Filter chips row: 48 tap row + 8 top + 8 bottom padding = 64
  // Total = 140
  @override
  double get minExtent => 140;

  @override
  double get maxExtent => 140;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final glassBorder = isDark
        ? AppColors.glassBorder
        : AppColors.glassBorderLight;

    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusLg,
      cornerSmoothing: 0.6,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        AppDimensions.spacingSm,
        AppDimensions.pagePaddingH,
        0,
      ),
      child: RepaintBoundary(
        child: ClipSmoothRect(
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
              shadows: isDark ? AppGlows.shadowSoft : AppGlows.shadowSoft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Search row + sort button ──
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.spacingMd,
                    AppDimensions.spacingMd,
                    AppDimensions.spacingMd,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: AppDimensions.comfortableTapTarget,
                          child: daftar_widgets.SearchBar(
                            hintText: searchHintText,
                            onDebouncedChanged: onSearchChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      _GlassSortButton(
                        tooltip: sortTooltip,
                        isDark: isDark,
                        onPressed: onSortPressed,
                      ),
                    ],
                  ),
                ),

                // ── Balance polarity filter chips ──
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.spacingMd,
                    AppDimensions.spacingSm,
                    AppDimensions.spacingMd,
                    AppDimensions.spacingSm,
                  ),
                  child: _BalanceFilterChips(
                    currentFilter: currentFilter,
                    onFilterChanged: onFilterChanged,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LedgerDetailHeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.searchHintText != searchHintText ||
        oldDelegate.sortTooltip != sortTooltip ||
        oldDelegate.onSortPressed != onSortPressed ||
        oldDelegate.onSearchChanged != onSearchChanged ||
        oldDelegate.currentFilter != currentFilter ||
        oldDelegate.onFilterChanged != onFilterChanged;
  }
}

// =============================================================================
// _BalanceFilterChips — inline polarity filters (All / Debt / Credit / Settled)
// =============================================================================

/// A horizontal row of squircle chips for filtering contacts by balance polarity.
///
/// **The math:**
///   - "عليه" (Debt): `netBalance < 0` — the contact owes the merchant
///   - "له" (Credit): `netBalance > 0` — the merchant owes the contact
///   - "مُسدّد" (Settled): `netBalance == 0` — fully squared
///   - "الكل" (All): no filter
class _BalanceFilterChips extends StatelessWidget {
  const _BalanceFilterChips({
    required this.currentFilter,
    required this.onFilterChanged,
    required this.isDark,
  });

  final String currentFilter;
  final ValueChanged<String> onFilterChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final chips = <_FilterChipData>[
      _FilterChipData(value: _filterAll, label: l10n.filterAll),
      _FilterChipData(value: _filterDebt, label: l10n.filterDebt),
      _FilterChipData(value: _filterCredit, label: l10n.filterCredit),
      _FilterChipData(value: _filterSettled, label: l10n.filterSettled),
    ];

    return SizedBox(
      height: AppDimensions.minTapTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppDimensions.spacingSm),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isSelected = chip.value == currentFilter;

          return _FilterChip(
            label: chip.label,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => onFilterChanged(chip.value),
          );
        },
      ),
    );
  }
}

class _FilterChipData {
  const _FilterChipData({required this.value, required this.label});
  final String value;
  final String label;
}

/// Individual filter chip with squircle geometry and Lapis-compliant styling.
///
/// Selected state uses `surface4` (dark) / `surface3Light` (light) with a
/// lapis400 0.5px border — the same treatment as the BalanceCard's currency
/// filter chips. This is NOT a solid lapis fill (Lapis Firewall).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedFill = isDark ? AppColors.surface4 : AppColors.surface3Light;
    final unselectedFill = isDark
        ? AppColors.surface3.withValues(alpha: 0.5)
        : AppColors.surface2Light.withValues(alpha: 0.6);
    final selectedBorder = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final unselectedBorder = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final selectedText = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final unselectedText = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DaftarTapTarget(
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          height: 32,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
          ),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: isSelected ? selectedFill : unselectedFill,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: AppDimensions.radiusSm,
                cornerSmoothing: 0.6,
              ),
              side: BorderSide(
                color: isSelected ? selectedBorder : unselectedBorder,
                width: AppDimensions.dividerThickness,
              ),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected ? selectedText : unselectedText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _GlassSortButton — toolbar action button
// =============================================================================

class _GlassSortButton extends StatefulWidget {
  const _GlassSortButton({
    required this.tooltip,
    required this.isDark,
    required this.onPressed,
  });

  final String tooltip;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  State<_GlassSortButton> createState() => _GlassSortButtonState();
}

class _GlassSortButtonState extends State<_GlassSortButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.isDark
        ? AppColors.surface4.withValues(alpha: 0.7)
        : AppColors.surface2Light;
    final border = widget.isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final iconColor = widget.isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.light());
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: Container(
            width: AppDimensions.comfortableTapTarget,
            height: AppDimensions.comfortableTapTarget,
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
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.sort_rounded,
              size: AppDimensions.iconMedium,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _AddContactFab — Lapis-bordered floating action button
// =============================================================================

/// FAB that follows Lapis Lux rules: monochrome surface fill + lapis border
/// + ctaRest glow. NOT a solid lapis fill (Lapis Firewall violation).
class _AddContactFab extends StatefulWidget {
  const _AddContactFab({
    required this.onPressed,
    required this.label,
    required this.isDark,
  });

  final VoidCallback onPressed;
  final String label;
  final bool isDark;

  @override
  State<_AddContactFab> createState() => _AddContactFabState();
}

class _AddContactFabState extends State<_AddContactFab> {
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
          scale: _pressed ? 0.95 : 1,
          duration: AppDimensions.animationFast,
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
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
                    Icons.person_add_rounded,
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

enum _LedgerPdfExportPhase { fetch, render, save, share, timeout }

class _LedgerExportFlowFailure implements Exception {
  _LedgerExportFlowFailure(this.failure);

  final Failure failure;
}

class _LedgerPdfExportException implements Exception {
  _LedgerPdfExportException(this.kind, this.detail);

  factory _LedgerPdfExportException.render(String detail) =>
      _LedgerPdfExportException(_LedgerPdfExportPhase.render, detail);
  factory _LedgerPdfExportException.save(String detail) =>
      _LedgerPdfExportException(_LedgerPdfExportPhase.save, detail);
  factory _LedgerPdfExportException.share(String detail) =>
      _LedgerPdfExportException(_LedgerPdfExportPhase.share, detail);
  factory _LedgerPdfExportException.timeout() =>
      _LedgerPdfExportException(_LedgerPdfExportPhase.timeout, 'timeout');

  final _LedgerPdfExportPhase kind;
  final String detail;
}
