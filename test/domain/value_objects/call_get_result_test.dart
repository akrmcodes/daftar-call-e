import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/value_objects/call_get_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('promised integer stays needsHuman false', () {
    final result = CallGetResult.fromJson(const {
      'runId': 'run-1',
      'status': 'completed',
      'terminal': true,
      'phoneMasked': '+…0100',
      'needsHuman': false,
      'structuredResult': {
        'outcome': 'promised',
        'promised_amount_minor': 1500,
        'promised_currency': 'USD',
        'promised_date': '2026-09-10',
      },
    });

    expect(result.needsHuman, isFalse);
    expect(result.structuredResult?.outcome, CallRunOutcome.promised);
    expect(result.structuredResult?.promisedAmountMinor, 1500);
    expect(result.deskStatus, CollectionsCallRowStatus.completed);
  });

  test('completed without collections outcome is success', () {
    final result = CallGetResult.fromJson(const {
      'runId': 'run-2',
      'status': 'completed',
      'terminal': true,
      'task_completed': true,
      'phoneMasked': '+…0100',
      'needsHuman': true,
    });

    expect(result.needsHuman, isFalse);
    expect(result.structuredResult, isNull);
    expect(result.deskStatus, CollectionsCallRowStatus.completed);
  });

  test('float promised amount is needsHuman and not stored as int', () {
    final result = CallGetResult.fromJson(const {
      'runId': 'run-3',
      'status': 'completed',
      'terminal': true,
      'phoneMasked': '+…0100',
      'needsHuman': false,
      'structured_result': {
        'outcome': 'promised',
        'promised_amount_minor': 1500.5,
      },
    });

    expect(result.needsHuman, isTrue);
    expect(result.structuredResult?.promisedAmountMinor, isNull);
    expect(result.structuredResult?.amountInvalid, isTrue);
    expect(result.deskStatus, CollectionsCallRowStatus.failed);
  });

  test('queued and planned map to planned desk status', () {
    for (final status in ['queued', 'planned', 'preparing', 'unknown']) {
      final result = CallGetResult.fromJson({
        'runId': 'run-planned',
        'status': status,
        'terminal': false,
        'phoneMasked': '+…0100',
        'needsHuman': false,
      });
      expect(result.deskStatus, CollectionsCallRowStatus.planned);
    }
  });

  test('in_progress maps to ringing', () {
    final result = CallGetResult.fromJson(const {
      'runId': 'run-ring',
      'status': 'in_progress',
      'terminal': false,
      'phoneMasked': '+…0100',
      'needsHuman': false,
    });
    expect(result.deskStatus, CollectionsCallRowStatus.ringing);
  });

  test('canceled maps to failed', () {
    final result = CallGetResult.fromJson(const {
      'runId': 'run-cancel',
      'status': 'canceled',
      'terminal': true,
      'phoneMasked': '+…0100',
      'needsHuman': false,
    });
    expect(result.deskStatus, CollectionsCallRowStatus.failed);
  });
}
