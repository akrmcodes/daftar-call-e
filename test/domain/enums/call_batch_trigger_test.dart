import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:flutter_test/flutter_test.dart';

/// §5.5 freeze: A-story close-day + HITL credit-limit B-trigger only.
void main() {
  test('CallBatchTrigger stays frozen to closeDay and creditLimit', () {
    expect(CallBatchTrigger.values, hasLength(2));
    expect(CallBatchTrigger.values, [
      CallBatchTrigger.closeDay,
      CallBatchTrigger.creditLimit,
    ]);
  });
}
