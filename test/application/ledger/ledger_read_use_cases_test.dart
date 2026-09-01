import 'package:daftar/application/ledger/get_archived_ledgers_use_case.dart';
import 'package:daftar/application/ledger/get_ledger_by_id_use_case.dart';
import 'package:daftar/application/ledger/preview_carry_forward_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockLedgerRepository extends Mock implements LedgerRepository {}

void main() {
  late MockLedgerRepository ledgerRepository;
  final now = DateTime.utc(2026, 6);

  Ledger testLedger(String id) {
    return Ledger(
      id: id,
      name: 'Ledger $id',
      type: LedgerType.custom,
      icon: 'folder',
      color: '#000000',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    ledgerRepository = MockLedgerRepository();
  });

  group('GetLedgerByIdUseCase', () {
    test('delegates to repository', () async {
      final sut = GetLedgerByIdUseCase(ledgerRepository);
      final ledger = testLedger('ledger-1');
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(ledger),
      );

      final result = await sut.execute('ledger-1');

      expect(result, Right<Failure, Ledger>(ledger));
    });
  });

  group('GetArchivedLedgersUseCase', () {
    test('watches archived ledgers from repository', () async {
      final sut = GetArchivedLedgersUseCase(ledgerRepository);
      final archived = [testLedger('archived-1')];
      when(() => ledgerRepository.watchArchived()).thenAnswer(
        (_) => Stream.value(archived),
      );

      final values = await sut.execute().toList();

      expect(values.single, archived);
    });
  });

  group('PreviewCarryForwardUseCase', () {
    test('delegates preview to repository', () async {
      final sut = PreviewCarryForwardUseCase(ledgerRepository);
      const preview = CarryForwardPreview(
        contactCount: 2,
        transactionCount: 5,
        totalsByCurrency: {'YER': 1000},
        sourceLedgerName: 'Source',
        targetLedgerName: 'Target',
      );
      when(
        () => ledgerRepository.previewCarryForward(
          sourceLedgerId: 'source',
          targetLedgerId: 'target',
        ),
      ).thenAnswer((_) async => const Right(preview));

      final result = await sut.execute(
        sourceLedgerId: 'source',
        targetLedgerId: 'target',
      );

      expect(result, const Right<Failure, CarryForwardPreview>(preview));
    });

    test('returns repository failure', () async {
      final sut = PreviewCarryForwardUseCase(ledgerRepository);
      when(
        () => ledgerRepository.previewCarryForward(
          sourceLedgerId: any(named: 'sourceLedgerId'),
          targetLedgerId: any(named: 'targetLedgerId'),
        ),
      ).thenAnswer(
        (_) async => const Left(ValidationFailure('invalid target')),
      );

      final result = await sut.execute(
        sourceLedgerId: 'source',
        targetLedgerId: 'target',
      );

      expect(result.isLeft(), isTrue);
    });
  });
}
