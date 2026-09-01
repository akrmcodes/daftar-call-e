import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/value_objects/reminder_eligible_contact_entry.dart';
import 'package:fpdart/fpdart.dart';

class GetReminderEligibleContactsUseCase {
  const GetReminderEligibleContactsUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  Future<Either<Failure, List<ReminderEligibleContactEntry>>> execute() {
    return _contactRepository.getContactsEligibleForAutomatedReminders();
  }
}
