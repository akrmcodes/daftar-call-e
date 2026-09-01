import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/core/utils/pdf_storage_service.dart';
import 'package:daftar/core/utils/statement_share.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:daftar/presentation/screens/contact/widgets/export_progress_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Outcome of preparing a contact statement PDF and presenting the share sheet.
class ShareContactStatementPdfResult {
  const ShareContactStatementPdfResult._(this.didShare, this.failure);

  /// Generate, save, or share failed.
  const ShareContactStatementPdfResult.failed(Failure failure)
      : this._(false, failure);

  /// Share sheet was presented.
  static const ShareContactStatementPdfResult shared =
      ShareContactStatementPdfResult._(true, null);

  /// Host unmounted; nothing to show.
  static const ShareContactStatementPdfResult cancelled =
      ShareContactStatementPdfResult._(false, null);

  /// Whether the OS share sheet was presented.
  final bool didShare;

  /// Localized via ErrorTranslator; never shown as [Failure.message].
  final Failure? failure;
}

/// Prepares a Drift statement, generates the PDF, and opens the share sheet.
///
/// Does not confirm an agent proposal. Used by the Collections Desk attach-PDF
/// path and by [shareAgentStatement].
Future<ShareContactStatementPdfResult> shareContactStatementPdf({
  required BuildContext context,
  required WidgetRef ref,
  required String contactId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final isRtl = Directionality.of(context) == TextDirection.rtl;

  final overlayCtrl = ExportProgressOverlay.show(
    context,
    title: l10n.exportStatement,
  );

  try {
    overlayCtrl.update(0.05, l10n.pdfPreparingData);
    final preparedResult = await ref
        .read(prepareContactStatementUseCaseProvider)
        .execute(contactId: contactId);
    final preparedFailure = preparedResult.getLeft().toNullable();
    if (preparedFailure != null) {
      return ShareContactStatementPdfResult.failed(preparedFailure);
    }
    final prepared = preparedResult.getRight().toNullable()!;

    if (!context.mounted) {
      overlayCtrl.dismiss();
      return ShareContactStatementPdfResult.cancelled;
    }

    final profile = await ref
        .read(resolvePdfMerchantProfileUseCaseProvider)
        .execute();

    late final List<int> pdfBytes;
    try {
      pdfBytes = await PdfGenerator.generateContactStatement(
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
        onProgress: overlayCtrl.update,
        merchantProfile: profile,
      );
    } on TimeoutException {
      return const ShareContactStatementPdfResult.failed(
        ValidationFailure(
          'PDF export timed out.',
          code: 'pdf_timeout',
        ),
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Contact statement PDF render failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const ShareContactStatementPdfResult.failed(
        ValidationFailure(
          'PDF render failed.',
          code: 'pdf_render_failed',
        ),
      );
    }

    final hasSpace = await ref.read(storageServiceProvider).hasEnoughSpace();
    if (!hasSpace) {
      return const ShareContactStatementPdfResult.failed(StorageFullFailure());
    }

    late final File savedFile;
    try {
      overlayCtrl.update(0.95, l10n.pdfSaving);
      savedFile = await PdfStorageService.saveStatement(
        pdfBytes: pdfBytes,
        contactName: prepared.contact.name,
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Contact statement PDF save failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const ShareContactStatementPdfResult.failed(
        ValidationFailure(
          'PDF save failed.',
          code: 'pdf_save_failed',
        ),
      );
    }

    overlayCtrl.complete(l10n.pdfComplete);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    overlayCtrl.dismiss();

    try {
      final shareResult = await StatementShare.shareStatementPdf(
        file: XFile(savedFile.path),
        shareTitle: l10n.shareStatement,
        shareSubject: l10n.statementShareSubject(prepared.contact.name),
      );
      if (shareResult.status == ShareResultStatus.dismissed) {
        // Android often reports [ShareResultStatus.unavailable] even after a
        // successful share; only an explicit dismiss keeps the row pending.
        return ShareContactStatementPdfResult.cancelled;
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Contact statement PDF share failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const ShareContactStatementPdfResult.failed(
        ValidationFailure(
          'PDF share failed.',
          code: 'pdf_share_failed',
        ),
      );
    }

    return ShareContactStatementPdfResult.shared;
  } on Object catch (error, stackTrace) {
    developer.log(
      'Contact statement export failed',
      error: error,
      stackTrace: stackTrace,
    );
    return const ShareContactStatementPdfResult.failed(
      ValidationFailure(
        'PDF render failed.',
        code: 'pdf_render_failed',
      ),
    );
  } finally {
    overlayCtrl.dismiss();
  }
}

/// Prepares a Drift statement, generates the PDF, opens the share sheet, then confirms.
Future<void> shareAgentStatement({
  required BuildContext context,
  required WidgetRef ref,
  required AgentProposal proposal,
}) async {
  final notifier = ref.read(closingAgentControllerProvider.notifier);
  final agentState = ref.read(closingAgentControllerProvider);
  if (agentState.confirmingProposalId != null) {
    return;
  }

  final payload = proposal.payload;
  final payloadId = payload is ProposeStatementPayload
      ? payload.contactId.trim()
      : '';
  final overrideId =
      agentState.contactIdByProposal[proposal.proposalId]?.trim() ?? '';
  final contactId = overrideId.isNotEmpty ? overrideId : payloadId;
  if (contactId.isEmpty) {
    notifier.failConfirming(
      const ValidationFailure(
        'Contact could not be resolved.',
        code: 'contact_unresolved',
      ),
    );
    return;
  }

  notifier.beginConfirming(proposal.proposalId);

  final result = await shareContactStatementPdf(
    context: context,
    ref: ref,
    contactId: contactId,
  );

  if (result.failure != null) {
    notifier.failConfirming(result.failure!);
    return;
  }
  if (!result.didShare) {
    notifier.clearConfirming();
    return;
  }

  await notifier.confirm(proposal);
}
