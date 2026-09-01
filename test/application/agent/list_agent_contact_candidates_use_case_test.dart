import 'package:daftar/application/agent/list_agent_contact_candidates_use_case.dart';
import 'package:daftar/application/agent/resolve_contact_hint_use_case.dart';
import 'package:daftar/application/contact/search_contacts_use_case.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSearchContactsUseCase extends Mock implements SearchContactsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  final now = DateTime.utc(2026, 8, 14);
  final contact = Contact(
    id: 'contact-1',
    ledgerId: 'ledger-1',
    name: 'Mohamed',
    avatarColor: '#000000',
    createdAt: now,
    updatedAt: now,
  );

  late MockSearchContactsUseCase search;
  late ListAgentContactCandidatesUseCase useCase;

  setUp(() {
    search = MockSearchContactsUseCase();
    useCase = ListAgentContactCandidatesUseCase(
      resolveContactHintUseCase: ResolveContactHintUseCase(
        searchContactsUseCase: search,
      ),
    );
  });

  test('blank hint returns no hits and does not search', () async {
    final result = await useCase.execute(contactHint: '  ');
    expect(result.getRight().toNullable(), isEmpty);
    verifyNever(
      () => search.execute(
        any(),
        excludeUserArchivedLedgers: any(named: 'excludeUserArchivedLedgers'),
      ),
    );
  });

  test('one hit is returned', () async {
    when(
      () => search.execute(
        'Mohamed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: contact,
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );

    final result = await useCase.execute(contactHint: 'Mohamed');
    expect(result.getRight().toNullable(), hasLength(1));
  });

  test('many hits are returned without picking a winner', () async {
    when(
      () => search.execute(
        'Mohamed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: contact,
          ledgerName: 'A',
          isLedgerUserArchived: false,
        ),
        ContactSearchHit(
          contact: contact.copyWith(id: 'contact-2'),
          ledgerName: 'B',
          isLedgerUserArchived: false,
        ),
      ]),
    );

    final result = await useCase.execute(contactHint: 'Mohamed');
    expect(result.getRight().toNullable(), hasLength(2));
  });
}
