import 'package:daftar/application/agent/extract_statement_contact_hint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips English statement phrasing', () {
    expect(extractStatementContactHint('statement for Mohamed'), 'Mohamed');
    expect(extractStatementContactHint('Statement for Mohamed Ali'), 'Mohamed Ali');
  });

  test('strips Arabic statement phrasing', () {
    expect(extractStatementContactHint('كشف حساب محمد'), 'محمد');
    expect(extractStatementContactHint('كشف محمد'), 'محمد');
    expect(extractStatementContactHint('كشف حساب لمحمد'), 'محمد');
    expect(extractStatementContactHint('كشف حساب لوليد'), 'وليد');
    expect(extractStatementContactHint('كشف حساب لاحمد عبدالله'), 'احمد عبدالله');
    expect(extractStatementContactHint('كشف لاحمد عبدالله'), 'لاحمد عبدالله');
  });

  test('blank remainder is null', () {
    expect(extractStatementContactHint('statement for'), isNull);
    expect(extractStatementContactHint('كشف حساب'), isNull);
  });
}
