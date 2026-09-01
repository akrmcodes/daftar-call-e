import 'package:daftar/application/agent/arabic_name_particles.dart';
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

  final now = DateTime.utc(2026, 8, 15);
  final ahmed = Contact(
    id: 'contact-ahmed',
    ledgerId: 'ledger-1',
    name: 'أحمد عبدالله',
    avatarColor: '#000000',
    createdAt: now,
    updatedAt: now,
  );

  late MockSearchContactsUseCase search;
  late ResolveContactHintUseCase useCase;

  setUp(() {
    search = MockSearchContactsUseCase();
    useCase = ResolveContactHintUseCase(searchContactsUseCase: search);
  });

  ContactSearchHit hit() {
    return ContactSearchHit(
      contact: ahmed,
      ledgerName: 'Customers',
      isLedgerUserArchived: false,
    );
  }

  test('collapse and expand عبد particles', () {
    expect(collapseAbdParticles('أحمد عبد الله'), 'أحمد عبدالله');
    expect(expandAbdParticles('أحمد عبدالله'), 'أحمد عبد الله');
    expect(stripArabicNamePrefix('لاحمد'), 'احمد');
    expect(stripFirstTokenPrefix('وليد'), 'ليد');
    expect(stripFirstTokenPrefix('لمحمد'), 'محمد');
    expect(stripFirstTokenPrefix('لاحمد عبدالله'), 'احمد عبدالله');
    expect(stripFirstTokenPrefix('بدر'), 'در');
  });

  test('spaced عبد الله unique-hits glued عبدالله', () async {
    when(
      () => search.execute(
        any(),
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.positionalArguments.first as String;
      if (query == 'أحمد عبدالله' || query == 'احمد عبدالله') {
        return Right([hit()]);
      }
      return const Right([]);
    });

    final result = await useCase.execute('أحمد عبد الله');
    expect(result.getRight().toNullable(), hasLength(1));
    expect(result.getRight().toNullable()!.single.contact.name, 'أحمد عبدالله');
  });

  test('وليد unique-hits original and never searches ليد first', () async {
    final walid = ahmed.copyWith(id: 'contact-walid', name: 'وليد');
    final walidHit = ContactSearchHit(
      contact: walid,
      ledgerName: 'Customers',
      isLedgerUserArchived: false,
    );
    final queries = <String>[];
    when(
      () => search.execute(
        any(),
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.positionalArguments.first as String;
      queries.add(query);
      if (query == 'وليد') {
        return Right([walidHit]);
      }
      return const Right([]);
    });

    final result = await useCase.execute('وليد');
    expect(result.getRight().toNullable(), hasLength(1));
    expect(result.getRight().toNullable()!.single.contact.name, 'وليد');
    expect(queries.first, 'وليد');
    expect(queries, isNot(contains('ليد')));
  });

  test('لمحمد unique-hits محمد via prefix-strip retry', () async {
    final mohamed = ahmed.copyWith(id: 'contact-mohamed', name: 'محمد');
    final mohamedHit = ContactSearchHit(
      contact: mohamed,
      ledgerName: 'Customers',
      isLedgerUserArchived: false,
    );
    when(
      () => search.execute(
        any(),
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.positionalArguments.first as String;
      if (query == 'محمد') {
        return Right([mohamedHit]);
      }
      return const Right([]);
    });

    final result = await useCase.execute('لمحمد');
    expect(result.getRight().toNullable(), hasLength(1));
    expect(result.getRight().toNullable()!.single.contact.name, 'محمد');
  });
}
