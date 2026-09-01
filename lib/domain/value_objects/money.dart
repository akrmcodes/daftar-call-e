import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:equatable/equatable.dart';

/// Represents a monetary amount with its associated currency.
///
/// All amounts are stored as [int] in the smallest unit of the currency
/// (e.g., 1500 = 15.00 YER with 2 decimal places). This eliminates
/// floating-point rounding errors — a non-negotiable requirement for
/// financial-grade data integrity.
///
/// Arithmetic operations are only valid between [Money] instances with
/// the same [currencyCode]. Cross-currency operations are FORBIDDEN
/// and will throw [ArgumentError].
///
/// ## Usage
/// ```dart
/// final debt = Money(amount: 1500, currencyCode: 'YER');
/// final payment = Money(amount: 500, currencyCode: 'YER');
/// final remaining = debt - payment; // Money(1000, 'YER')
/// ```
class Money extends Equatable {

  /// Creates a [Money] value.
  ///
  /// [amount] is in the smallest currency unit (fils, halalas, cents).
  /// [currencyCode] is a non-empty ISO 4217 code.
  const Money({
    required this.amount,
    required this.currencyCode,
  });

  /// A zero-value [Money] for the given [currencyCode].
  const Money.zero(this.currencyCode) : amount = 0;
  /// The monetary amount in the smallest currency unit.
  ///
  /// For SAR/USD with 2 decimal places: 1500 = 15.00.
  /// For YER with 0 decimal places: 1500 = 1500.
  /// NEVER use double or Decimal for this value.
  final int amount;

  /// ISO 4217 currency code (e.g., 'YER', 'SAR', 'USD').
  final String currencyCode;

  /// Whether this amount is zero.
  bool get isZero => amount == 0;

  /// Whether this amount is positive (greater than zero).
  bool get isPositive => amount > 0;

  /// Whether this amount is negative (less than zero).
  bool get isNegative => amount < 0;

  /// Returns the absolute value of this [Money].
  Money get abs => Money(amount: amount.abs(), currencyCode: currencyCode);

  /// Returns the negated value of this [Money].
  Money operator -() => Money(amount: -amount, currencyCode: currencyCode);

  /// Adds two [Money] values with the same currency.
  ///
  /// Throws [ArgumentError] if currencies do not match.
  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount: amount + other.amount, currencyCode: currencyCode);
  }

  /// Subtracts [other] from this [Money].
  ///
  /// Throws [ArgumentError] if currencies do not match.
  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amount: amount - other.amount, currencyCode: currencyCode);
  }

  /// Multiplies the amount by an integer scalar.
  ///
  /// Useful for quantity-based calculations (e.g., 3 × unit price).
  Money operator *(int multiplier) {
    return Money(amount: amount * multiplier, currencyCode: currencyCode);
  }

  /// Returns `true` if this [Money] is greater than [other].
  ///
  /// Throws [ArgumentError] if currencies do not match.
  bool operator >(Money other) {
    _assertSameCurrency(other);
    return amount > other.amount;
  }

  /// Returns `true` if this [Money] is greater than or equal to [other].
  ///
  /// Throws [ArgumentError] if currencies do not match.
  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return amount >= other.amount;
  }

  /// Returns `true` if this [Money] is less than [other].
  ///
  /// Throws [ArgumentError] if currencies do not match.
  bool operator <(Money other) {
    _assertSameCurrency(other);
    return amount < other.amount;
  }

  /// Returns `true` if this [Money] is less than or equal to [other].
  ///
  /// Throws [ArgumentError] if currencies do not match.
  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return amount <= other.amount;
  }

  /// Formats using the precision rule for this [currencyCode].
  String displayForCurrency() =>
      display(CurrencyPrecision.decimalPlacesForCode(currencyCode));

  /// Formats the amount for display using [decimalPlaces].
  ///
  /// Example: `Money(1500, 'SAR').display(2)` → `'15.00'`
  /// Example: `Money(1500, 'YER').display(0)` → `'1500'`
  String display(int decimalPlaces) {
    if (decimalPlaces <= 0) return amount.toString();

    final isNegative = amount < 0;
    final abs = amount.abs();
    final divisor = CurrencyPrecision.minorUnitFactor(decimalPlaces);
    final wholePart = abs ~/ divisor;
    final fractionalPart = abs % divisor;
    final body =
        '$wholePart.${fractionalPart.toString().padLeft(decimalPlaces, '0')}';
    return isNegative ? '-$body' : body;
  }

  /// Asserts that [other] has the same currency as this instance.
  void _assertSameCurrency(Money other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Cannot perform arithmetic on different currencies: '
        '$currencyCode vs ${other.currencyCode}. '
        'Cross-currency operations are forbidden.',
      );
    }
  }

  @override
  List<Object?> get props => [amount, currencyCode];

  @override
  String toString() => 'Money($amount $currencyCode)';
}
