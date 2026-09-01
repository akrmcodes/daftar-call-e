import 'package:daftar/data/models/contact_model.dart';

class ContactSearchRow {
  const ContactSearchRow({
    required this.contact,
    required this.ledgerName,
    required this.isLedgerUserArchived,
  });

  final ContactModel contact;
  final String ledgerName;
  final bool isLedgerUserArchived;
}
