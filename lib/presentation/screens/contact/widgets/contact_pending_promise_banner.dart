import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/constants/promised_calendar_day.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/shared/widgets/daftar_permission_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Khazna info banner for the latest pending CALL-E promise on a contact.
///
/// Display-only — never payment-green, never ledger money.
class ContactPendingPromiseBanner extends ConsumerWidget {
  /// Creates the banner for [contactId].
  const ContactPendingPromiseBanner({
    required this.contactId,
    super.key,
  });

  /// Drift contact id.
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPromises = ref.watch(pendingCollectionPromisesProvider(contactId));
    final promises = asyncPromises.value;
    if (promises == null || promises.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final latest = promises.first;
    final l10n = AppLocalizations.of(context)!;
    final amountText = _formatAmount(latest);
    final dateText = _formatDate(context, latest.promisedDate);
    if (amountText == null || dateText == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingSm,
          AppDimensions.pagePaddingH,
          AppDimensions.spacingXs,
        ),
        child: DaftarPermissionBanner(
          message: l10n.contactPendingPromiseBody(amountText, dateText),
          semanticsLabel: l10n.contactPendingPromiseSemantics(
            amountText,
            dateText,
          ),
        ),
      ),
    );
  }

  String? _formatAmount(CollectionPromise promise) {
    final symbol = _symbolFor(promise.currencyCode);
    return MoneyUtil.formatWithSymbolForCode(
      promise.amountMinor,
      promise.currencyCode,
      symbol,
    );
  }

  String? _formatDate(BuildContext context, String promisedDate) {
    final normalized = PromisedCalendarDay.tryParse(promisedDate);
    if (normalized == null) {
      return null;
    }
    final parts = normalized.split('-');
    final date = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date);
  }

  static String _symbolFor(String code) {
    final normalized = code.trim().toUpperCase();
    for (final currency in BuiltInCurrencies.all) {
      if (currency.code == normalized) {
        return currency.symbol;
      }
    }
    return normalized;
  }
}
