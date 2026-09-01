import 'package:equatable/equatable.dart';

/// Suggestion returned from the transaction autocomplete search.
///
/// [lastAmount] is stored in the smallest currency unit to preserve the
/// project's integer-money rule.
final class ItemSuggestion extends Equatable {
  /// Creates an item suggestion.
  const ItemSuggestion({required this.itemName, this.lastAmount});

  /// The suggested item name.
  final String itemName;

  /// The most recent amount recorded for this item.
  final int? lastAmount;

  @override
  List<Object?> get props => [itemName, lastAmount];
}
