import 'dart:async';

import 'package:daftar/application/agent/collections_statement_pdf_renderer.dart';
import 'package:daftar/application/agent/compose_collections_reminder_draft_use_case.dart';
import 'package:daftar/application/contact/prepare_contact_statement_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:daftar/domain/value_objects/collections_reminder_draft.dart';
import 'package:daftar/domain/value_objects/email_send_batch.dart';
import 'package:fpdart/fpdart.dart';

/// SMTP send-batch for Collections Approve. Providers call this use case only.
class DispatchCollectionsEmailUseCase {
  /// Creates the use case.
  const DispatchCollectionsEmailUseCase({
    required PrepareContactStatementUseCase prepareContactStatement,
    required CollectionsStatementPdfRenderer pdfRenderer,
    required ClosingAgentRuntimeRepository runtimeRepository,
    required ComposeCollectionsReminderDraftUseCase composeDraft,
  })  : _prepareContactStatement = prepareContactStatement,
        _pdfRenderer = pdfRenderer,
        _runtimeRepository = runtimeRepository,
        _composeDraft = composeDraft;

  final PrepareContactStatementUseCase _prepareContactStatement;
  final CollectionsStatementPdfRenderer _pdfRenderer;
  final ClosingAgentRuntimeRepository _runtimeRepository;
  final ComposeCollectionsReminderDraftUseCase _composeDraft;

  static final RegExp _pathChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Caps at [ClosingAgentConstants.maxEmailRecipients]. Missing email / PDF
  /// over 5 MB / timeout → that row `failed`. Text-only (`!attachPdf`) still
  /// calls send-batch without PDF bytes.
  ///
  /// [onRows] is invoked as rows change so the Desk can show progress even when
  /// the terminal [Either] is [Left] (`needsHuman` / network).
  Future<Either<Failure, DispatchCollectionsEmailResult>> execute({
    required List<CollectionsDeskRow> rows,
    required String locale,
    required String storeName,
    required String batchId,
    required String correlationId,
    required bool isRtl,
    void Function(List<CollectionsDeskRow> rows)? onRows,
  }) async {
    if (rows.length > ClosingAgentConstants.maxEmailRecipients) {
      return const Left(
        ValidationFailure(
          'Collections email batch cannot exceed '
          '${ClosingAgentConstants.maxEmailRecipients} recipients.',
          code: 'collections_email_cap',
        ),
      );
    }

    var working = [...rows];
    void emit() => onRows?.call(List<CollectionsDeskRow>.unmodifiable(working));

    final recipients = <EmailSendBatchRecipient>[];
    final pdfs = <String, List<int>>{};

    for (var i = 0; i < working.length; i++) {
      working[i] = working[i].copyWith(
        status: CollectionsDeskRowStatus.sending,
      );
      emit();

      final prepared = await _prepareRow(
        row: working[i],
        locale: locale,
        storeName: storeName,
        isRtl: isRtl,
      );
      working[i] = prepared.row;
      emit();
      if (prepared.recipient != null) {
        recipients.add(prepared.recipient!);
        if (prepared.pdfBytes != null) {
          pdfs[prepared.recipient!.contactId] = prepared.pdfBytes!;
        }
      }
    }

    if (recipients.isEmpty) {
      return Right(
        DispatchCollectionsEmailResult(
          rows: List<CollectionsDeskRow>.unmodifiable(working),
          metrics: CollectionsQueueMetrics.fromRows(working),
        ),
      );
    }

    final remote = await _runtimeRepository.sendEmailBatch(
      EmailSendBatchRequest(
        batchId: batchId,
        correlationId: correlationId,
        locale: locale,
        recipients: recipients,
        pdfsByContactId: pdfs,
      ),
    );

    return remote.fold(
      (failure) {
        for (var i = 0; i < working.length; i++) {
          if (working[i].status == CollectionsDeskRowStatus.sending) {
            working[i] = working[i].copyWith(
              status: CollectionsDeskRowStatus.pending,
            );
          }
        }
        emit();
        return Left(failure);
      },
      (response) {
        working = _applyRemoteResults(working, response);
        emit();
        final metrics = CollectionsQueueMetrics.fromRows(working);
        final result = DispatchCollectionsEmailResult(
          rows: List<CollectionsDeskRow>.unmodifiable(working),
          metrics: metrics,
        );
        if (response.needsHuman) {
          return Left(_smtpHumanFailure(response));
        }
        return Right(result);
      },
    );
  }

  static const _senderMisconfigured = {
    'from_user_mismatch',
    'smtp_secret_unavailable',
  };

  static AuthFailure _smtpHumanFailure(EmailSendBatchResponse response) {
    final reason = response.results
        .map((row) => row.smtpMessage?.trim() ?? '')
        .firstWhere((message) => message.isNotEmpty, orElse: () => '');
    if (_senderMisconfigured.contains(reason)) {
      return const AuthFailure(
        'SMTP sender is not configured on Cloud Run.',
        code: 'smtp_sender_misconfigured',
      );
    }
    return const AuthFailure(
      'SMTP needs a human (App Password rejected).',
      code: 'smtp_needs_human',
    );
  }

  Future<({
    CollectionsDeskRow row,
    EmailSendBatchRecipient? recipient,
    List<int>? pdfBytes,
  })> _prepareRow({
    required CollectionsDeskRow row,
    required String locale,
    required String storeName,
    required bool isRtl,
  }) async {
    final draft = _draftFor(row, locale: locale, storeName: storeName);
    final withDraft = row.copyWith(
      subject: draft.subject,
      body: draft.body,
      customerName: draft.customerName,
      storeName: draft.storeName,
      amountLine: draft.amountLine,
      ctaLine: draft.ctaLine,
      note: draft.note,
    );

    final to = ContactEmail.normalize(row.candidate.email);
    if (to == null || !ContactEmail.isValid(to)) {
      return (
        row: withDraft.copyWith(status: CollectionsDeskRowStatus.failed),
        recipient: null,
        pdfBytes: null,
      );
    }

    if (!row.attachPdf) {
      return (
        row: withDraft,
        recipient: EmailSendBatchRecipient(
          contactId: row.candidate.contactId,
          to: to,
          subject: draft.subject,
          customerName: draft.customerName,
          storeName: draft.storeName,
          amountLine: draft.amountLine,
          ctaLine: draft.ctaLine,
          note: draft.note,
        ),
        pdfBytes: null,
      );
    }

    final preparedResult = await _prepareContactStatement.execute(
      contactId: row.candidate.contactId,
    );
    final preparedFailure = preparedResult.getLeft().toNullable();
    if (preparedFailure != null) {
      return (
        row: withDraft.copyWith(status: CollectionsDeskRowStatus.failed),
        recipient: null,
        pdfBytes: null,
      );
    }
    final prepared = preparedResult.getRight().toNullable()!;

    late final List<int> pdfBytes;
    try {
      pdfBytes = await _pdfRenderer.render(
        prepared: prepared,
        isRtl: isRtl,
      );
    } on TimeoutException {
      return (
        row: withDraft.copyWith(status: CollectionsDeskRowStatus.failed),
        recipient: null,
        pdfBytes: null,
      );
    } on Object {
      return (
        row: withDraft.copyWith(status: CollectionsDeskRowStatus.failed),
        recipient: null,
        pdfBytes: null,
      );
    }

    if (pdfBytes.length > ClosingAgentConstants.maxPdfBytes) {
      return (
        row: withDraft.copyWith(status: CollectionsDeskRowStatus.failed),
        recipient: null,
        pdfBytes: null,
      );
    }

    final filename = statementFilename(row.candidate.name);
    return (
      row: withDraft,
      recipient: EmailSendBatchRecipient(
        contactId: row.candidate.contactId,
        to: to,
        subject: draft.subject,
        customerName: draft.customerName,
        storeName: draft.storeName,
        amountLine: draft.amountLine,
        ctaLine: draft.ctaLine,
        note: draft.note,
        filename: filename,
      ),
      pdfBytes: pdfBytes,
    );
  }

  CollectionsReminderDraft _draftFor(
    CollectionsDeskRow row, {
    required String locale,
    required String storeName,
  }) {
    if (row.subject.isNotEmpty &&
        row.body.isNotEmpty &&
        row.amountLine.isNotEmpty) {
      return CollectionsReminderDraft(
        subject: row.subject,
        body: row.body,
        customerName: row.customerName.isNotEmpty
            ? row.customerName
            : row.candidate.name,
        storeName: row.storeName.isNotEmpty ? row.storeName : storeName,
        amountLine: row.amountLine,
        ctaLine: row.ctaLine,
        note: row.note,
      );
    }
    return _composeDraft.execute(
      candidate: row.candidate,
      tone: row.toneBand,
      locale: locale,
      storeName: storeName,
    );
  }

  static List<CollectionsDeskRow> _applyRemoteResults(
    List<CollectionsDeskRow> working,
    EmailSendBatchResponse response,
  ) {
    final byId = {
      for (final result in response.results) result.contactId: result,
    };
    return [
      for (final row in working)
        if (row.status == CollectionsDeskRowStatus.failed)
          row
        else
          _mapRemote(row, byId[row.candidate.contactId]),
    ];
  }

  static CollectionsDeskRow _mapRemote(
    CollectionsDeskRow row,
    EmailSendRowResult? remote,
  ) {
    if (remote == null) {
      return row.copyWith(status: CollectionsDeskRowStatus.failed);
    }
    if (remote.status == EmailSendRowRemoteStatus.skippedDuplicate) {
      return row.copyWith(
        status: CollectionsDeskRowStatus.sent,
        smtpMessageId: remote.smtpMessageId,
        smtpCode: remote.smtpCode,
      );
    }
    if (remote.isAcceptedSend) {
      return row.copyWith(
        status: CollectionsDeskRowStatus.sent,
        smtpMessageId: remote.smtpMessageId,
        smtpCode: remote.smtpCode,
      );
    }
    return row.copyWith(
      status: CollectionsDeskRowStatus.failed,
      smtpMessageId: remote.smtpMessageId,
      smtpCode: remote.smtpCode,
    );
  }

  /// `daftar-{sanitized}.pdf` — strips path separators.
  static String statementFilename(String contactName) {
    final stripped = contactName
        .trim()
        .replaceAll(_pathChars, '')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
    final stem = stripped.isEmpty ? 'contact' : stripped;
    return 'daftar-$stem.pdf';
  }
}

/// Desk rows plus report metrics after SMTP (or local-only failures).
class DispatchCollectionsEmailResult {
  /// Creates a dispatch result.
  const DispatchCollectionsEmailResult({
    required this.rows,
    required this.metrics,
  });

  final List<CollectionsDeskRow> rows;
  final CollectionsQueueMetrics metrics;
}
