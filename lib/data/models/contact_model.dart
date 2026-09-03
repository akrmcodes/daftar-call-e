import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/contact.dart' as domain;
import 'package:drift/drift.dart' as drift;

/// Data-layer representation of a contact.
///
/// The model is the authoritative bridge between the domain entity and the
/// generated Drift row/companion types.
class ContactModel {
  /// Creates a contact data model.
  const ContactModel({
    required this.id,
    required this.ledgerId,
    required this.name,
    required this.phone,
    required this.notes,
    required this.creditLimit,
    required this.creditCurrency,
    required this.avatarColor,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.isDeleted = false,
    this.isArchived = false,
    this.doNotCall = false,
    this.syncVersion = 0,
  });

  /// Builds a data model from a domain entity.
  factory ContactModel.fromDomain(domain.Contact contact) {
    return ContactModel(
      id: contact.id,
      ledgerId: contact.ledgerId,
      name: contact.name,
      phone: contact.phone,
      email: contact.email,
      notes: contact.notes,
      creditLimit: contact.creditLimit,
      creditCurrency: contact.creditCurrency,
      avatarColor: contact.avatarColor,
      createdAt: contact.createdAt,
      updatedAt: contact.updatedAt,
      isDeleted: contact.isDeleted,
      isArchived: contact.isArchived,
      doNotCall: contact.doNotCall,
      syncVersion: contact.syncVersion,
    );
  }

  /// Builds a data model from a Drift row.
  factory ContactModel.fromDrift(db.Contact contact) {
    return ContactModel(
      id: contact.id,
      ledgerId: contact.ledgerId,
      name: contact.name,
      phone: contact.phone,
      email: contact.email,
      notes: contact.notes,
      creditLimit: contact.creditLimit,
      creditCurrency: contact.creditCurrency,
      avatarColor: contact.avatarColor,
      createdAt: contact.createdAt,
      updatedAt: contact.updatedAt,
      isDeleted: contact.isDeleted,
      isArchived: contact.isArchived,
      doNotCall: contact.doNotCall,
      syncVersion: contact.syncVersion,
    );
  }

  /// Rebuilds a model from a populated Drift companion.
  factory ContactModel.fromCompanion(db.ContactsCompanion companion) {
    return ContactModel(
      id: _requiredValue(companion.id, 'id'),
      ledgerId: _requiredValue(companion.ledgerId, 'ledgerId'),
      name: _requiredValue(companion.name, 'name'),
      phone: _optionalValue(companion.phone, null),
      email: _optionalValue(companion.email, null),
      notes: _optionalValue(companion.notes, null),
      creditLimit: _optionalValue(companion.creditLimit, null),
      creditCurrency: _optionalValue(companion.creditCurrency, null),
      avatarColor: _requiredValue(companion.avatarColor, 'avatarColor'),
      createdAt: _requiredValue(companion.createdAt, 'createdAt'),
      updatedAt: _requiredValue(companion.updatedAt, 'updatedAt'),
      isDeleted: _optionalValue(companion.isDeleted, false),
      isArchived: _optionalValue(companion.isArchived, false),
      doNotCall: _optionalValue(companion.doNotCall, false),
      syncVersion: _optionalValue(companion.syncVersion, 0),
    );
  }

  /// Unique identifier.
  final String id;

  /// Parent ledger identifier.
  final String ledgerId;

  /// Contact display name.
  final String name;

  /// Optional phone number.
  final String? phone;

  /// Optional email for Collections SMTP.
  final String? email;

  /// Optional notes.
  final String? notes;

  /// Optional credit limit in the smallest currency unit.
  final int? creditLimit;

  /// Optional currency code for the credit limit.
  final String? creditCurrency;

  /// Avatar color for list tiles and headers.
  final String avatarColor;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-update timestamp.
  final DateTime updatedAt;

  /// Soft-delete flag.
  final bool isDeleted;

  /// Archive-first import flag.
  final bool isArchived;

  /// Omit from Confirm & Call when true.
  final bool doNotCall;

  /// Sync conflict resolution version.
  final int syncVersion;

  /// Converts this model back to the domain entity.
  domain.Contact toDomain() {
    return domain.Contact(
      id: id,
      ledgerId: ledgerId,
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      creditLimit: creditLimit,
      creditCurrency: creditCurrency,
      avatarColor: avatarColor,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      isArchived: isArchived,
      doNotCall: doNotCall,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.Contact toDrift() {
    return db.Contact(
      id: id,
      ledgerId: ledgerId,
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      creditLimit: creditLimit,
      creditCurrency: creditCurrency,
      avatarColor: avatarColor,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      isArchived: isArchived,
      doNotCall: doNotCall,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.ContactsCompanion toCompanion() {
    return toDrift().toCompanion(false);
  }
}

T _requiredValue<T>(drift.Value<T> value, String fieldName) {
  if (!value.present) {
    throw StateError(
      'Missing required field "$fieldName" in Drift companion.',
    );
  }
  return value.value;
}

T _optionalValue<T>(drift.Value<T> value, T fallback) {
  return value.present ? value.value : fallback;
}
