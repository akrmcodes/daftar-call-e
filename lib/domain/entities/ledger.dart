import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger.freezed.dart';

/// Represents a merchant's debt ledger grouping contacts by category.
///
/// Ledgers are the top-level organizational unit. Each contact belongs
/// to exactly one ledger. Free-tier users are limited to 1 ledger.
///
/// Fields:
/// - [id]: UUID v4 primary key.
/// - [name]: User-defined ledger name (e.g., "حسابات دكان الحي").
/// - [type]: Business category — customers, suppliers, personal, or custom.
/// - [icon]: Icon identifier for UI display.
/// - [color]: Hex color string for visual differentiation.
/// - [sortOrder]: Manual ordering position in ledger list.
/// - [createdAt]: UTC timestamp of creation.
/// - [updatedAt]: UTC timestamp of last modification.
/// - [isDeleted]: Soft-delete flag. True = logically deleted.
/// - [syncVersion]: Monotonically increasing version for sync conflict resolution.
@freezed
abstract class Ledger with _$Ledger {
  const factory Ledger({
    required String id,
    required String name,
    required LedgerType type,
    required String icon,
    required String color,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isDeleted,
    @Default(false) bool isArchived,
    @Default(false) bool isUserArchived,
    String? carryForwardTargetLedgerId,
    @Default(0) int syncVersion,
  }) = _Ledger;
}
