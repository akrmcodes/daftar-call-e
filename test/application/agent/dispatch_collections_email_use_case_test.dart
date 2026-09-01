import 'dart:async';

import 'package:daftar/application/agent/collections_statement_pdf_renderer.dart';
import 'package:daftar/application/agent/compose_collections_reminder_draft_use_case.dart';
import 'package:daftar/application/agent/dispatch_collections_email_use_case.dart';
import 'package:daftar/application/contact/prepare_contact_statement_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/contact_statement_export.dart';
import 'package:daftar/domain/value_objects/email_send_batch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockPrepareContactStatementUseCase extends Mock
    implements PrepareContactStatementUseCase {}

class MockCollectionsStatementPdfRenderer extends Mock
    implements CollectionsStatementPdfRenderer {}

class MockClosingAgentRuntimeRepository extends Mock
    implements ClosingAgentRuntimeRepository {}

void main() {
  late MockPrepareContactStatementUseCase prepare;
  late MockCollectionsStatementPdfRenderer pdf;
  late MockClosingAgentRuntimeRepository runtime;
  late DispatchCollectionsEmailUseCase useCase;

  final created = DateTime.utc(2026, 8, 20);
  late ContactStatementExport export;

  setUpAll(() {
    registerFallbackValue(
      const EmailSendBatchRequest(
        batchId: 'batch',
        correlationId: 'corr',
        locale: 'en',
        recipients: [],
        pdfsByContactId: {},
      ),
    );
  });

  setUp(() {
    prepare = MockPrepareContactStatementUseCase();
    pdf = MockCollectionsStatementPdfRenderer();
    runtime = MockClosingAgentRuntimeRepository();
    useCase = DispatchCollectionsEmailUseCase(
      prepareContactStatement: prepare,
      pdfRenderer: pdf,
      runtimeRepository: runtime,
      composeDraft: const ComposeCollectionsReminderDraftUseCase(),
    );
    export = ContactStatementExport(
      contact: Contact(
        id: 'a',
        ledgerId: 'ledger',
        name: 'na',
        avatarColor: '#000000',
        createdAt: created,
        updatedAt: created,
        email: 'a@example.com',
      ),
      balance: ContactBalance(
        contactId: 'a',
        currencyCode: 'YER',
        totalDebt: 500,
        totalPayment: 0,
        netBalance: -500,
        lastUpdatedAt: created,
      ),
      transactions: const [],
    );
    registerFallbackValue(export);
  });

  CollectionsDeskRow deskRow({
    required String id,
    String? email,
    bool attachPdf = true,
  }) {
    return CollectionsDeskRow(
      candidate: CollectionsCandidate(
        contactId: id,
        name: 'n$id',
        email: email,
        phone: '+96770000000$id',
        ledgerId: 'ledger',
        netBalance: -500,
        currencyCode: 'YER',
        ageDays: 12,
        toneBand: ReminderToneBand.reminder,
      ),
      subject: 'Al-Ghanem Store: outstanding balance 500 YER',
      body:
          'Hello n$id, this is Al-Ghanem Store. Your outstanding balance is 500 YER. Please arrange payment when you can.  Thank you.',
      customerName: 'n$id',
      storeName: 'Al-Ghanem Store',
      amountLine: '500 YER',
      ctaLine: 'Please arrange payment when you can.',
      toneBand: ReminderToneBand.reminder,
      attachPdf: attachPdf,
    );
  }

  void stubPrepareOk() {
    when(
      () => prepare.execute(contactId: any(named: 'contactId')),
    ).thenAnswer((_) async => Right(export));
  }

  const batchId = '11111111-1111-4111-8111-111111111111';
  const correlationId = '22222222-2222-4222-8222-222222222222';

  Future<Either<Failure, DispatchCollectionsEmailResult>> run(
    List<CollectionsDeskRow> rows, {
    void Function(List<CollectionsDeskRow> rows)? onRows,
  }) {
    return useCase.execute(
      rows: rows,
      locale: 'en',
      storeName: 'Al-Ghanem Store',
      batchId: batchId,
      correlationId: correlationId,
      isRtl: false,
      onRows: onRows,
    );
  }

  test('cap over 20 is ValidationFailure', () async {
    final rows = [
      for (var i = 0; i < 21; i++) deskRow(id: '$i', email: 'a$i@example.com'),
    ];
    final result = await run(rows);
    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    expect(result.getLeft().toNullable()?.code, 'collections_email_cap');
    verifyNever(() => runtime.sendEmailBatch(any()));
  });

  test('missing email is failed and does not call send-batch', () async {
    final result = await run([deskRow(id: 'a')]);
    final ok = result.getRight().toNullable()!;
    expect(ok.rows.single.status, CollectionsDeskRowStatus.failed);
    expect(ok.metrics.failed, 1);
    expect(ok.metrics.sent, 0);
    expect(ok.metrics.opened, 0);
    verifyNever(() => runtime.sendEmailBatch(any()));
  });

  test('invalid email is failed, never opened, and does not call send-batch', () async {
    final result = await run([deskRow(id: 'a', email: 'not-an-email')]);
    final ok = result.getRight().toNullable()!;
    expect(ok.rows.single.status, CollectionsDeskRowStatus.failed);
    expect(ok.metrics.opened, 0);
    expect(ok.metrics.failed, 1);
    verifyNever(() => runtime.sendEmailBatch(any()));
  });

  test('text-only rows still call send-batch without PDF bytes', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer((_) async => List<int>.filled(8, 2));
    when(() => runtime.sendEmailBatch(any())).thenAnswer((invocation) async {
      final request =
          invocation.positionalArguments.first as EmailSendBatchRequest;
      return Right(
        EmailSendBatchResponse(
          batchId: batchId,
          needsHuman: false,
          results: [
            for (final recipient in request.recipients)
              EmailSendRowResult(
                contactId: recipient.contactId,
                toMasked: '***@example.com',
                status: EmailSendRowRemoteStatus.sent,
                smtpCode: 250,
                smtpMessageId: '<mid-${recipient.contactId}@gmail.com>',
              ),
          ],
        ),
      );
    });

    final result = await run([
      deskRow(id: 'a', email: 'a@example.com'),
      deskRow(id: 'b', email: 'b@example.com', attachPdf: false),
    ]);
    final ok = result.getRight().toNullable()!;
    expect(ok.rows.map((row) => row.status), [
      CollectionsDeskRowStatus.sent,
      CollectionsDeskRowStatus.sent,
    ]);
    final request =
        verify(() => runtime.sendEmailBatch(captureAny())).captured.single
            as EmailSendBatchRequest;
    expect(request.recipients, hasLength(2));
    expect(request.pdfsByContactId.keys, ['a']);
    expect(
      request.recipients.firstWhere((row) => row.contactId == 'b').filename,
      isNull,
    );
    verify(() => prepare.execute(contactId: 'a')).called(1);
    verifyNever(() => prepare.execute(contactId: 'b'));
  });

  test('PDF over 5 MB is failed', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer(
      (_) async => List<int>.filled(ClosingAgentConstants.maxPdfBytes + 1, 1),
    );
    final result = await run([deskRow(id: 'a', email: 'a@example.com')]);
    expect(
      result.getRight().toNullable()!.rows.single.status,
      CollectionsDeskRowStatus.failed,
    );
    verifyNever(() => runtime.sendEmailBatch(any()));
  });

  test('PDF timeout is failed', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenThrow(TimeoutException('pdf'));
    final result = await run([deskRow(id: 'a', email: 'a@example.com')]);
    expect(
      result.getRight().toNullable()!.rows.single.status,
      CollectionsDeskRowStatus.failed,
    );
    verifyNever(() => runtime.sendEmailBatch(any()));
  });

  test('sent only with 250 and Message-ID', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer((_) async => List<int>.filled(8, 2));
    when(() => runtime.sendEmailBatch(any())).thenAnswer(
      (_) async => const Right(
        EmailSendBatchResponse(
          batchId: batchId,
          needsHuman: false,
          results: [
            EmailSendRowResult(
              contactId: 'a',
              toMasked: 'a***@example.com',
              status: EmailSendRowRemoteStatus.sent,
              smtpCode: 250,
              smtpMessageId: '<mid@gmail.com>',
            ),
          ],
        ),
      ),
    );

    final accepted = await run([deskRow(id: 'a', email: 'a@example.com')]);
    expect(
      accepted.getRight().toNullable()!.rows.single.status,
      CollectionsDeskRowStatus.sent,
    );

    when(() => runtime.sendEmailBatch(any())).thenAnswer(
      (_) async => const Right(
        EmailSendBatchResponse(
          batchId: batchId,
          needsHuman: false,
          results: [
            EmailSendRowResult(
              contactId: 'a',
              toMasked: 'a***@example.com',
              status: EmailSendRowRemoteStatus.sent,
              smtpCode: 250,
              smtpMessageId: '',
            ),
          ],
        ),
      ),
    );
    final rejected = await run([deskRow(id: 'a', email: 'a@example.com')]);
    expect(
      rejected.getRight().toNullable()!.rows.single.status,
      CollectionsDeskRowStatus.failed,
    );
  });

  test('Dio/network error is NetworkFailure and does not mark sent', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer((_) async => List<int>.filled(8, 2));
    when(() => runtime.sendEmailBatch(any())).thenAnswer(
      (_) async => const Left(
        NetworkFailure(
          'Closing Agent request failed',
          code: 'closing_agent_request_failed',
        ),
      ),
    );
    late List<CollectionsDeskRow> captured;
    final result = await run(
      [deskRow(id: 'a', email: 'a@example.com')],
      onRows: (rows) => captured = rows,
    );
    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    expect(result.getLeft().toNullable()?.code, 'closing_agent_request_failed');
    expect(captured.single.status, isNot(CollectionsDeskRowStatus.sent));
  });

  test('needsHuman is AuthFailure smtp_needs_human', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer((_) async => List<int>.filled(8, 2));
    when(() => runtime.sendEmailBatch(any())).thenAnswer(
      (_) async => const Right(
        EmailSendBatchResponse(
          batchId: batchId,
          needsHuman: true,
          results: [
            EmailSendRowResult(
              contactId: 'a',
              toMasked: 'a***@example.com',
              status: EmailSendRowRemoteStatus.failed,
              smtpCode: 535,
            ),
          ],
        ),
      ),
    );
    late List<CollectionsDeskRow> captured;
    final result = await run(
      [deskRow(id: 'a', email: 'a@example.com')],
      onRows: (rows) => captured = rows,
    );
    expect(result.getLeft().toNullable(), isA<AuthFailure>());
    expect(result.getLeft().toNullable()?.code, 'smtp_needs_human');
    expect(captured.single.status, CollectionsDeskRowStatus.failed);
  });

  test('needsHuman from_user_mismatch is smtp_sender_misconfigured', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer((_) async => List<int>.filled(8, 2));
    when(() => runtime.sendEmailBatch(any())).thenAnswer(
      (_) async => const Right(
        EmailSendBatchResponse(
          batchId: batchId,
          needsHuman: true,
          results: [
            EmailSendRowResult(
              contactId: 'a',
              toMasked: 'a***@example.com',
              status: EmailSendRowRemoteStatus.failed,
              smtpMessage: 'from_user_mismatch',
            ),
          ],
        ),
      ),
    );
    final result = await run(
      [deskRow(id: 'a', email: 'a@example.com')],
    );
    expect(result.getLeft().toNullable(), isA<AuthFailure>());
    expect(result.getLeft().toNullable()?.code, 'smtp_sender_misconfigured');
  });

  test('multipart request never includes an App Password', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer((_) async => List<int>.filled(8, 2));
    late EmailSendBatchRequest captured;
    when(() => runtime.sendEmailBatch(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.first as EmailSendBatchRequest;
      return Right(
        EmailSendBatchResponse(
          batchId: captured.batchId,
          needsHuman: false,
          results: [
            EmailSendRowResult(
              contactId: captured.recipients.single.contactId,
              toMasked: 'a***@example.com',
              status: EmailSendRowRemoteStatus.sent,
              smtpCode: 250,
              smtpMessageId: '<mid@gmail.com>',
            ),
          ],
        ),
      );
    });

    await run([deskRow(id: 'a', email: 'a@example.com')]);

    final encoded = captured.manifestJson().toString().toLowerCase();
    expect(encoded, isNot(contains('app password')));
    expect(encoded, isNot(contains('gmail_smtp')));
    expect(captured.manifestJson().containsKey('password'), isFalse);
    expect(captured.pdfsByContactId['a'], isNotNull);
  });

  test('skippedDuplicate is treated as sent', () async {
    stubPrepareOk();
    when(
      () => pdf.render(
        prepared: any(named: 'prepared'),
        isRtl: any(named: 'isRtl'),
      ),
    ).thenAnswer((_) async => List<int>.filled(8, 2));
    when(() => runtime.sendEmailBatch(any())).thenAnswer(
      (_) async => const Right(
        EmailSendBatchResponse(
          batchId: batchId,
          needsHuman: false,
          results: [
            EmailSendRowResult(
              contactId: 'a',
              toMasked: 'a***@example.com',
              status: EmailSendRowRemoteStatus.skippedDuplicate,
              smtpCode: 250,
              smtpMessageId: '<mid@gmail.com>',
            ),
          ],
        ),
      ),
    );
    final result = await run([deskRow(id: 'a', email: 'a@example.com')]);
    expect(
      result.getRight().toNullable()!.rows.single.status,
      CollectionsDeskRowStatus.sent,
    );
  });
}
