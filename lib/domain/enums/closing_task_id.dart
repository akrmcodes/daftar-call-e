/// Device-owned close-the-day checklist steps (plan = execution log).
enum ClosingTaskId {
  /// Reconcile today's merchant calendar day.
  bindLedger,

  /// Collect debt entries for `localDay`.
  collectDebts,

  /// Collect payment entries for `localDay`.
  collectPayments,

  /// Tally per-currency integer totals.
  tallyTotals,

  /// Stamp the Drift day snapshot.
  stampSnapshot,

  /// Prepare the vault backup payload.
  prepareVaultPayload,

  /// Upload backup to Drive (or queue / skip).
  sealDriveBackup,

  /// Scan aging balances.
  scanAging,

  /// Rank accounts by urgency.
  rankUrgency,

  /// Build the SMTP send-set (cap 20).
  buildSendSet,

  /// Merchant reviews Collections Desk (SMTP approve).
  openCollectionsDesk,

  /// Compose the day report from ritual data.
  composeReport,

  /// Present the sealed day report.
  presentSeal,
}

/// Canonical task order for the Closing Agent taskmaster.
abstract final class ClosingTaskOrder {
  /// All tasks in execution order.
  static const ordered = <ClosingTaskId>[
    ClosingTaskId.bindLedger,
    ClosingTaskId.collectDebts,
    ClosingTaskId.collectPayments,
    ClosingTaskId.tallyTotals,
    ClosingTaskId.stampSnapshot,
    ClosingTaskId.prepareVaultPayload,
    ClosingTaskId.sealDriveBackup,
    ClosingTaskId.scanAging,
    ClosingTaskId.rankUrgency,
    ClosingTaskId.buildSendSet,
    ClosingTaskId.openCollectionsDesk,
    ClosingTaskId.composeReport,
    ClosingTaskId.presentSeal,
  ];

  /// Index of [id] in [ordered], or -1.
  static int indexOf(ClosingTaskId id) => ordered.indexOf(id);

  /// Next task after [id], or null at the end.
  static ClosingTaskId? next(ClosingTaskId id) {
    final index = indexOf(id);
    if (index < 0 || index >= ordered.length - 1) {
      return null;
    }
    return ordered[index + 1];
  }
}
