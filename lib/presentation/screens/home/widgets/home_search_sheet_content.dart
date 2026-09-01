import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/shared/widgets/archived_badge_chip.dart';
import 'package:daftar/presentation/shared/widgets/search_bar.dart'
    as daftar_widgets;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The body of the global search bottom sheet on the home screen.
///
/// Uses [ContactSearchQuery] to drive the search query state and
/// [contactSearchResultsProvider] to reactively display matching contacts.
class HomeSearchSheetContent extends ConsumerStatefulWidget {
  const HomeSearchSheetContent({required this.onContactTap, super.key});

  final ValueChanged<Contact> onContactTap;

  @override
  ConsumerState<HomeSearchSheetContent> createState() =>
      _HomeSearchSheetContentState();
}

class _HomeSearchSheetContentState
    extends ConsumerState<HomeSearchSheetContent> {
  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) return;
      try {
        ref.read(contactSearchQueryProvider.notifier).clear();
      } on Object {
        // Ignore — provider scope may have been torn down.
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final colors = context.colorScheme;
    final asyncResults = ref.watch(contactSearchResultsProvider);
    final query = ref.watch(contactSearchQueryProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        daftar_widgets.SearchBar(
          autofocus: true,
          hintText: l10n.searchContacts,
          onDebouncedChanged: (value) {
            ref.read(contactSearchQueryProvider.notifier).setQuery(value);
          },
          onCleared: () {
            ref.read(contactSearchQueryProvider.notifier).clear();
          },
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        if (query.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacing3xl,
            ),
            child: Center(
              child: Text(
                l10n.searchHint,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
                ),
              ),
            ),
          )
        else
          asyncResults.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppDimensions.spacing3xl,
              ),
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing3xl,
              ),
              child: Center(
                child: Text(
                  l10n.loadingError,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ),
            data: (either) => either.fold(
              (failure) => Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacing3xl,
                ),
                child: Center(
                  child: Text(
                    ErrorTranslator.message(l10n, failure),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              ),
              (hits) {
                if (hits.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacing3xl,
                    ),
                    child: Center(
                      child: Text(
                        l10n.noContactsYet,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.inkMuted
                              : AppColors.inkMutedLight,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < hits.length; i++) ...[
                      HomeSearchResultTile(
                        hit: hits[i],
                        onTap: () => widget.onContactTap(hits[i].contact),
                      ),
                      if (i < hits.length - 1)
                        Divider(
                          height: 1,
                          color: isDark
                              ? AppColors.borderSubtle
                              : AppColors.borderSubtleLight,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// A single search result row showing contact name and phone.
class HomeSearchResultTile extends StatelessWidget {
  const HomeSearchResultTile({
    required this.hit,
    required this.onTap,
    super.key,
  });

  final ContactSearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final onSurface =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final contact = hit.contact;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingXs,
          vertical: AppDimensions.spacingMd,
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: AppDimensions.iconMedium,
              color: muted,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hit.isLedgerUserArchived) ...[
                        const SizedBox(width: AppDimensions.spacingXs),
                        ArchivedBadgeChip(
                          label: l10n.contactSearchArchivedBadge,
                        ),
                      ],
                    ],
                  ),
                  if (contact.phone != null && contact.phone!.isNotEmpty)
                    Text(
                      contact.phone!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (hit.ledgerName.isNotEmpty)
                    Text(
                      hit.ledgerName,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimensions.iconMedium,
              color: muted,
            ),
          ],
        ),
      ),
    );
  }
}
