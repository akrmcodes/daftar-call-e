import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/ledger_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps a [LedgerListTile] with a reactive contact count from the DB.
class LedgerTileWithCount extends ConsumerWidget {
  const LedgerTileWithCount({
    required this.ledger,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
    required this.onTap,
    super.key,
  });

  final Ledger ledger;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(contactCountProvider(ledger.id)).value ?? 0;

    return LedgerListTile(
      ledger: ledger,
      contactCount: count,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      onArchive: onArchive,
    );
  }
}
