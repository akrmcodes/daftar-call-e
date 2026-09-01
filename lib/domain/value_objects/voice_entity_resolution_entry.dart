import 'package:equatable/equatable.dart';

class VoiceEntityResolutionEntry extends Equatable {
  const VoiceEntityResolutionEntry({
    required this.contactId,
    required this.contactName,
    required this.ledgerId,
  });

  final String contactId;
  final String contactName;
  final String ledgerId;

  @override
  List<Object?> get props => [contactId, contactName, ledgerId];
}
