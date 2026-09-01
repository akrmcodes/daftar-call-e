import 'package:daftar/application/contact/get_contact_by_id_use_case.dart';
import 'package:daftar/application/contact/get_reminder_eligible_contacts_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/value_objects/reminder_eligible_contact_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late MockContactRepository contactRepository;
  final now = DateTime.utc(2026, 6);

  Contact testContact() {
    return Contact(
      id: 'contact-1',
      ledgerId: 'ledger-1',
      name: 'Ali',
      avatarColor: '#5C6BC0',
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    contactRepository = MockContactRepository();
  });

  group('GetContactByIdUseCase', () {
    test('returns ValidationFailure when id is empty', () async {
      final sut = GetContactByIdUseCase(contactRepository);

      final result = await sut.execute('  ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'contact_id_required'),
        (_) => fail('expected failure'),
      );
      verifyNever(() => contactRepository.getById(any()));
    });

    test('delegates to repository', () async {
      final sut = GetContactByIdUseCase(contactRepository);
      final contact = testContact();
      when(() => contactRepository.getById('contact-1')).thenAnswer(
        (_) async => Right(contact),
      );

      final result = await sut.execute('contact-1');

      expect(result, Right<Failure, Contact>(contact));
    });
  });

  group('GetReminderEligibleContactsUseCase', () {
    test('delegates to repository', () async {
      final sut = GetReminderEligibleContactsUseCase(contactRepository);
      const entries = [
        ReminderEligibleContactEntry(
          contactId: 'c-1',
          contactName: 'Ali',
          ledgerId: 'l-1',
          phone: '+967712345678',
        ),
      ];
      when(
        () => contactRepository.getContactsEligibleForAutomatedReminders(),
      ).thenAnswer((_) async => const Right(entries));

      final result = await sut.execute();

      expect(
        result,
        const Right<Failure, List<ReminderEligibleContactEntry>>(entries),
      );
    });

    test('returns repository failure', () async {
      final sut = GetReminderEligibleContactsUseCase(contactRepository);
      when(
        () => contactRepository.getContactsEligibleForAutomatedReminders(),
      ).thenAnswer(
        (_) async => const Left(DatabaseFailure('read failed')),
      );

      final result = await sut.execute();

      expect(result.isLeft(), isTrue);
    });
  });
}
