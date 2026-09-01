class ReminderEligibleContactRow {
  const ReminderEligibleContactRow({
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
}
