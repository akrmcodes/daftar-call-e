import 'package:equatable/equatable.dart';

/// Live-ledger contact row for dual-rail collections outreach (Appendix D).
class CollectionsOutreachContactEntry extends Equatable {
  const CollectionsOutreachContactEntry({
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

  @override
  List<Object?> get props => [
        contactId,
        contactName,
        ledgerId,
        phone,
        email,
        doNotCall,
      ];
}
