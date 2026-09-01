import 'package:daftar/application/entitlement/entitlement_limit_helper.dart';
import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Creates a new contact after validating name uniqueness and workspace limits.
class CreateContactUseCase {
  const CreateContactUseCase(
    this._contactRepository,
    this._ledgerRepository,
    this._activationRepository,
  );

  final ContactRepository _contactRepository;
  final LedgerRepository _ledgerRepository;
  final ActivationRepository _activationRepository;

  Future<Either<Failure, Contact>> execute({
    required String ledgerId,
    required String name,
    String? phone,
    String? email,
    String? notes,
    int? creditLimit,
    String? creditCurrency,
    String? avatarColor,
    bool saveAsArchived = false,
  }) async {
    final trimmedName = name.trim();
    final normalizedName = trimmedName.normalizeArabic();
    if (normalizedName.isEmpty) {
      return const Left(
        ValidationFailure(
          'Contact name is required.',
          code: 'contact_name_required',
        ),
      );
    }

    if (!ContactEmail.isValid(email)) {
      return const Left(
        ValidationFailure(
          'Contact email is invalid.',
          code: 'contact_email_invalid',
        ),
      );
    }

    final ledgerResult = await _ledgerRepository.getById(ledgerId);
    if (ledgerResult.isLeft()) {
      return Left(ledgerResult.getLeft().toNullable()!);
    }

    final archivedFailure = rejectIfUserArchived(
      ledgerResult.getRight().toNullable()!,
    );
    if (archivedFailure != null) {
      return Left(archivedFailure.getLeft().toNullable()!);
    }

    final existingContacts = await _contactRepository
        .watchByLedger(ledgerId)
        .first;
    final normalizedTargetName = _normalizedName(normalizedName);
    final duplicateExists = existingContacts.any(
      (contact) => _normalizedName(contact.name) == normalizedTargetName,
    );
    if (duplicateExists) {
      return const Left(
        ValidationFailure(
          'Name already exists',
          code: 'contact_name_exists',
        ),
      );
    }

    final activeCountResult = await _contactRepository.getActiveCount();
    final activeCount = activeCountResult.getRight().toNullable();
    if (activeCount == null) {
      return Left(activeCountResult.getLeft().toNullable()!);
    }

    if (!saveAsArchived) {
      final entitlement = await _activationRepository.getEntitlement();
      if (!entitlement.canAddContact(activeCount)) {
        return Left(
          EntitlementLimitHelper.contactLimit(entitlement, activeCount),
        );
      }
    }

    final now = DateTime.now().toUtc();
    final contact = Contact(
      id: UuidUtil.generate(),
      ledgerId: ledgerId,
      name: trimmedName,
      phone: _normalizeOptionalText(phone),
      email: ContactEmail.normalize(email),
      notes: _normalizeOptionalText(notes),
      creditLimit: creditLimit,
      creditCurrency: _normalizeCurrencyCode(creditCurrency),
      avatarColor: _resolveAvatarColor(normalizedName, avatarColor),
      createdAt: now,
      updatedAt: now,
      isArchived: saveAsArchived,
    );

    return _contactRepository.create(
      CreateContactParams(
        ledgerId: contact.ledgerId,
        name: contact.name,
        phone: contact.phone,
        email: contact.email,
        notes: contact.notes,
        creditLimit: contact.creditLimit,
        creditCurrency: contact.creditCurrency,
        avatarColor: contact.avatarColor,
        isArchived: saveAsArchived,
      ),
    );
  }

  static String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  static String? _normalizeCurrencyCode(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed.toUpperCase();
  }

  static String _resolveAvatarColor(String name, String? avatarColor) {
    final trimmedAvatarColor = avatarColor?.trim();
    if (trimmedAvatarColor != null && trimmedAvatarColor.isNotEmpty) {
      return trimmedAvatarColor;
    }

    return _defaultAvatarColors[_stableIndex(name)];
  }

  static int _stableIndex(String value) {
    var sum = 0;
    for (final codeUnit in value.codeUnits) {
      sum = (sum + codeUnit) & 0x7fffffff;
    }

    return sum % _defaultAvatarColors.length;
  }

  static String _normalizedName(String value) =>
      value.normalizeArabic().toLowerCase();

  static const List<String> _defaultAvatarColors = [
    '#5C6BC0',
    '#26A69A',
    '#EF5350',
    '#AB47BC',
    '#42A5F5',
    '#FFA726',
    '#66BB6A',
    '#EC407A',
    '#8D6E63',
    '#78909C',
  ];
}
