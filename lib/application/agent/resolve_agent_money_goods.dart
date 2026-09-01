/// Maps Closing Agent money fields onto Drift `itemName` / `description`.
///
/// Quick Add persists goods as `itemName`. Legacy envelopes only had `note`
/// (often spoken goods). Empty `itemName` + non-empty `note` → treat `note`
/// as goods. Duplicate item/note keeps `itemName` and drops the copy.
({String? itemName, String? note}) resolveAgentMoneyGoods({
  String? itemName,
  String? note,
}) {
  final item = itemName?.trim();
  final remark = note?.trim();
  final hasItem = item != null && item.isNotEmpty;
  final hasRemark = remark != null && remark.isNotEmpty;
  if (!hasItem && !hasRemark) {
    return (itemName: null, note: null);
  }
  if (!hasItem) {
    return (itemName: remark, note: null);
  }
  if (!hasRemark || item == remark) {
    return (itemName: item, note: null);
  }
  return (itemName: item, note: remark);
}
