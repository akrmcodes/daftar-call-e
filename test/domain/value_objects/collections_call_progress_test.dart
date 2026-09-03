import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('callingIndex counts non-planned rows only', () {
    const progress = CollectionsCallProgress(
      results: [
        CollectionsCallProgressRow(
          contactId: 'a',
          status: CollectionsCallRowStatus.planned,
        ),
        CollectionsCallProgressRow(
          contactId: 'b',
          status: CollectionsCallRowStatus.planned,
        ),
        CollectionsCallProgressRow(
          contactId: 'c',
          status: CollectionsCallRowStatus.completed,
        ),
      ],
    );

    expect(progress.total, 3);
    expect(progress.callingIndex, 1);
  });

  test('all planned yields callingIndex zero', () {
    const progress = CollectionsCallProgress(
      results: [
        CollectionsCallProgressRow(
          contactId: 'a',
          status: CollectionsCallRowStatus.planned,
        ),
      ],
    );

    expect(progress.callingIndex, 0);
  });
}
