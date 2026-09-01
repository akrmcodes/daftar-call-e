import 'package:equatable/equatable.dart';

class ReminderEligibleContactEntry extends Equatable {
  const ReminderEligibleContactEntry({
    required this.contactId,
    required this.contactName,
    required this.ledgerId,
    this.phone,
    this.email,
  });

  final String contactId;
  final String contactName;
  final String ledgerId;
  final String? phone;
  final String? email;

  @override
  List<Object?> get props => [
        contactId,
        contactName,
        ledgerId,
        phone,
        email,
      ];
}
