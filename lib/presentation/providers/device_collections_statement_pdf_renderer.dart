import 'package:daftar/application/agent/collections_statement_pdf_renderer.dart';
import 'package:daftar/application/merchant/resolve_pdf_merchant_profile_use_case.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/domain/value_objects/contact_statement_export.dart';
import 'package:flutter/widgets.dart';

/// Isolate PDF renderer for Collections SMTP (no share sheet).
class DeviceCollectionsStatementPdfRenderer
    implements CollectionsStatementPdfRenderer {
  /// Creates a renderer bound to [locale].
  const DeviceCollectionsStatementPdfRenderer({
    required this.locale,
    this.resolveMerchantProfile,
  });

  /// `ar` or `en`.
  final String locale;

  /// Optional branded PDF header (Pro).
  final ResolvePdfMerchantProfileUseCase? resolveMerchantProfile;

  @override
  Future<List<int>> render({
    required ContactStatementExport prepared,
    required bool isRtl,
  }) async {
    final l10n = lookupAppLocalizations(Locale(locale));
    final profile = await resolveMerchantProfile?.execute();
    return PdfGenerator.generateContactStatement(
      contact: prepared.contact,
      contactBalance: prepared.balance,
      transactions: prepared.transactions,
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
      merchantProfile: profile,
    );
  }
}
