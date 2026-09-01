import 'package:daftar/domain/entities/ledger.dart' show Ledger;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact.freezed.dart';

/// Represents a person (customer, supplier, or individual) who has a
/// financial relationship with the merchant.
///
/// Each contact belongs to exactly one [Ledger] via [ledgerId]. Contacts
/// carry optional metadata (phone, notes, credit limit) and support
/// soft deletion and sync versioning.
///
/// Fields:
/// - [id]: UUID v4 primary key.
/// - [ledgerId]: FK to the parent ledger.
/// - [name]: Contact's display name (Arabic names common).
/// - [phone]: Optional phone number for WhatsApp/call integration.
/// - [email]: Optional email for Collections SMTP.
/// - [notes]: Optional free-text notes about the contact.
/// - [creditLimit]: Optional maximum debt threshold in smallest currency unit.
/// - [creditCurrency]: Currency code for the credit limit (e.g., 'YER').
/// - [avatarColor]: Hex color string for the contact's avatar.
/// - [createdAt]: UTC timestamp of creation.
/// - [updatedAt]: UTC timestamp of last modification.
/// - [isDeleted]: Soft-delete flag.
/// - [syncVersion]: Version counter for sync conflict resolution.
@freezed
abstract class Contact with _$Contact {
  const factory Contact({
    required String id,
    required String ledgerId,
    required String name,
    required String avatarColor,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? phone,
    String? email,
    String? notes,
    int? creditLimit,
    String? creditCurrency,
    @Default(false) bool isDeleted,
    @Default(false) bool isArchived,
    @Default(0) int syncVersion,
  }) = _Contact;
}
