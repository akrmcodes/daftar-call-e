import 'package:daftar/domain/entities/contact.dart';
import 'package:equatable/equatable.dart';

class ContactSearchHit extends Equatable {
  const ContactSearchHit({
    required this.contact,
    required this.ledgerName,
    required this.isLedgerUserArchived,
  });

  final Contact contact;
  final String ledgerName;
  final bool isLedgerUserArchived;

  @override
  List<Object?> get props => [contact, ledgerName, isLedgerUserArchived];
}
