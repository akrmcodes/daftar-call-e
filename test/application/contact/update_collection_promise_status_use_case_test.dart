import 'package:daftar/application/contact/update_collection_promise_status_use_case.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/domain/repositories/collection_call_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCollectionCallRepository extends Mock
    implements CollectionCallRepository {}

void main() {
  late MockCollectionCallRepository repository;
  late UpdateCollectionPromiseStatusUseCase useCase;

  setUpAll(() {
    registerFallbackValue(CollectionPromiseStatus.kept);
  });

  setUp(() {
    repository = MockCollectionCallRepository();
    useCase = UpdateCollectionPromiseStatusUseCase(
      collectionCallRepository: repository,
    );
  });

  final promise = CollectionPromise(
    id: 'promise-1',
    contactId: 'contact-1',
    runId: 'run-1',
    amountMinor: 1500,
    currencyCode: 'USD',
    promisedDate: '2026-09-10',
    status: CollectionPromiseStatus.kept,
    updatedAt: DateTime.utc(2026, 9, 8),
  );

  test('rejects blank promise id', () async {
    final result = await useCase.execute(
      promiseId: '  ',
      status: CollectionPromiseStatus.kept,
    );

    expect(result.isLeft(), isTrue);
    expect(
      result.getLeft().toNullable()?.code,
      'promise_id_required',
    );
    verifyNever(() => repository.updatePromiseStatus(
      promiseId: any(named: 'promiseId'),
      status: any(named: 'status'),
    ));
  });

  test('rejects pending target status', () async {
    final result = await useCase.execute(
      promiseId: 'promise-1',
      status: CollectionPromiseStatus.pending,
    );

    expect(result.isLeft(), isTrue);
    expect(
      result.getLeft().toNullable()?.code,
      'promise_status_not_terminal',
    );
    verifyNever(() => repository.updatePromiseStatus(
      promiseId: any(named: 'promiseId'),
      status: any(named: 'status'),
    ));
  });

  test('persists kept status via repository', () async {
    when(
      () => repository.updatePromiseStatus(
        promiseId: 'promise-1',
        status: CollectionPromiseStatus.kept,
      ),
    ).thenAnswer((_) async => Right(promise));

    final result = await useCase.execute(
      promiseId: 'promise-1',
      status: CollectionPromiseStatus.kept,
    );

    expect(result.getRight().toNullable(), promise);
    verify(
      () => repository.updatePromiseStatus(
        promiseId: 'promise-1',
        status: CollectionPromiseStatus.kept,
      ),
    ).called(1);
  });

  test('persists broken status via repository', () async {
    when(
      () => repository.updatePromiseStatus(
        promiseId: 'promise-1',
        status: CollectionPromiseStatus.broken,
      ),
    ).thenAnswer(
      (_) async => Right(
        promise.copyWith(status: CollectionPromiseStatus.broken),
      ),
    );

    final result = await useCase.execute(
      promiseId: 'promise-1',
      status: CollectionPromiseStatus.broken,
    );

    expect(
      result.getRight().toNullable()?.status,
      CollectionPromiseStatus.broken,
    );
  });
}

extension on CollectionPromise {
  CollectionPromise copyWith({CollectionPromiseStatus? status}) {
    return CollectionPromise(
      id: id,
      contactId: contactId,
      runId: runId,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      promisedDate: promisedDate,
      status: status ?? this.status,
      updatedAt: updatedAt,
    );
  }
}
