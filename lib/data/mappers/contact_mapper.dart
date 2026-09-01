import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/domain/entities/contact.dart' as domain;

/// Seamless conversions for contact domain, data, and Drift types.
extension ContactDomainMapper on domain.Contact {
  /// Converts a domain contact to the data-layer model.
  ContactModel toModel() => ContactModel.fromDomain(this);

  /// Converts a domain contact directly to a Drift row.
  db.Contact toDrift() => toModel().toDrift();

  /// Converts a domain contact to a Drift companion.
  db.ContactsCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift contact rows.
extension ContactDriftMapper on db.Contact {
  /// Converts a Drift contact row to the data-layer model.
  ContactModel toModel() => ContactModel.fromDrift(this);

  /// Converts a Drift contact row back to the domain entity.
  domain.Contact toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift contact companions.
extension ContactCompanionMapper on db.ContactsCompanion {
  /// Converts a Drift contact companion to the data-layer model.
  ContactModel toModel() => ContactModel.fromCompanion(this);

  /// Converts a Drift contact companion back to the domain entity.
  domain.Contact toDomain() => toModel().toDomain();

  /// Converts a Drift contact companion to a Drift row.
  db.Contact toDrift() => toModel().toDrift();
}
