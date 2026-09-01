import 'package:daftar/application/entitlement/entitlement_limit_helper.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Creates a new ledger after validating the input and enforcing limits.
class CreateLedgerUseCase {
  const CreateLedgerUseCase(
    this._ledgerRepository,
    this._activationRepository,
  );

  final LedgerRepository _ledgerRepository;
  final ActivationRepository _activationRepository;

  Future<Either<Failure, Ledger>> execute({
    required String name,
    required LedgerType type,
    required String icon,
    required int color,
    bool saveAsArchived = false,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return const Left(
        ValidationFailure(
          'Ledger name is required.',
          code: 'ledger_name_required',
        ),
      );
    }

    final activeCountResult = await _ledgerRepository.getActiveCount();
    final activeCount = activeCountResult.getRight().toNullable();
    if (activeCount == null) {
      return Left(activeCountResult.getLeft().toNullable()!);
    }

    if (!saveAsArchived) {
      final entitlement = await _activationRepository.getEntitlement();
      if (!entitlement.canAddLedger(activeCount)) {
        return Left(
          EntitlementLimitHelper.ledgerLimit(entitlement, activeCount),
        );
      }
    }

    final now = DateTime.now().toUtc();
    final createdLedger = Ledger(
      id: UuidUtil.generate(),
      name: normalizedName,
      type: type,
      icon: icon.trim(),
      color: _toHexColorString(color),
      sortOrder: activeCount,
      createdAt: now,
      updatedAt: now,
      isArchived: saveAsArchived,
    );

    return _ledgerRepository.create(
      CreateLedgerParams(
        name: createdLedger.name,
        type: createdLedger.type,
        icon: createdLedger.icon,
        color: createdLedger.color,
        isArchived: saveAsArchived,
      ),
    );
  }

  String _toHexColorString(int color) {
    final hex = color.toUnsigned(32).toRadixString(16).toUpperCase();
    final rgb = hex.length > 6
        ? hex.substring(hex.length - 6)
        : hex.padLeft(6, '0');
    return '#$rgb';
  }
}
