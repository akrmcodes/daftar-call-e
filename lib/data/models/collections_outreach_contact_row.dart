class CollectionsOutreachContactRow {
  const CollectionsOutreachContactRow({
    required this.contactId,
    required this.contactName,
    required this.ledgerId,
    this.phone,
    this.email,
    this.doNotCall = false,
  });

  final String contactId;
  final String contactName;
  final String ledgerId;
  final String? phone;
  final String? email;
  final bool doNotCall;
}
