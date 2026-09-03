/// Device-owned lifecycle for a collection call batch.
enum CallBatchStatus {
  planned,
  dryRun,
  running,
  completed,
  failed,
}
