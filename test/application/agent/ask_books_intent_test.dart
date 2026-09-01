import 'package:daftar/application/agent/answer_ask_books_use_case.dart';
import 'package:daftar/application/agent/ask_books_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyAsk', () {
    test('capture goals with amounts are not ask', () {
      expect(classifyAsk('Mohamed owes 500'), isNull);
      expect(classifyAsk('عليه خمسمائة'), isNull);
      expect(classifyAsk('دين'), isNull);
      expect(AnswerAskBooksUseCase.looksLikeAsk('Mohamed owes 500'), isFalse);
    });

    test('user-reported named balance sentences', () {
      expect(
        classifyAsk('How much debt does Mohammed still owe?'),
        AskBooksIntent.namedBalance,
      );
      expect(
        classifyAsk("What is Mohammed's remaining balance?"),
        AskBooksIntent.namedBalance,
      );
      expect(classifyAsk('كم على محمد'), AskBooksIntent.namedBalance);
      expect(classifyAsk('كم دين محمد'), AskBooksIntent.namedBalance);
      expect(classifyAsk('كم عليه محمد'), AskBooksIntent.namedBalance);
      expect(classifyAsk('قديش عليه محمد'), AskBooksIntent.namedBalance);
      expect(classifyAsk('كم متبقي دين على محمد'), AskBooksIntent.namedBalance);
      expect(classifyAsk('كم رصيد محمد'), AskBooksIntent.namedBalance);
      expect(classifyAsk('كم حساب محمد'), AskBooksIntent.namedBalance);
    });

    test('last payment and last debt', () {
      expect(
        classifyAsk('What was his last payment amount?'),
        AskBooksIntent.lastPayment,
      );
      expect(
        classifyAsk('how much did Mohamed pay'),
        AskBooksIntent.lastPayment,
      );
      expect(classifyAsk('آخر دفعة لمحمد'), AskBooksIntent.lastPayment);
      expect(classifyAsk('آخر دين لمحمد'), AskBooksIntent.lastDebt);
    });

    test('overdue vs largest', () {
      expect(
        classifyAsk('Who are the customers with overdue payments?'),
        AskBooksIntent.overdueList,
      );
      expect(
        classifyAsk('Who has a large outstanding debt?'),
        AskBooksIntent.largestOutstanding,
      );
      expect(classifyAsk('أكبر دين'), AskBooksIntent.largestOutstanding);
      expect(classifyAsk('من صاحب أكبر دين؟'), AskBooksIntent.largestOutstanding);
      expect(classifyAsk('من صاحب أقل دين؟'), AskBooksIntent.smallestOutstanding);
      expect(classifyAsk('المتأخرين'), AskBooksIntent.overdueList);
      expect(classifyAsk('كشف حساب لمحمد'), isNull);
    });
  });

  group('extractAskNameHint', () {
    test('strips remaining so FTS is not AND leftover', () {
      expect(
        extractAskNameHint("What is Mohammed's remaining balance?"),
        'Mohammed',
      );
      expect(
        extractAskNameHint('How much debt does Mohammed still owe?'),
        'Mohammed',
      );
      expect(extractAskNameHint('كم دين محمد'), 'محمد');
      expect(extractAskNameHint('كم على محمد'), 'محمد');
      expect(extractAskNameHint('كم متبقي دين على محمد'), 'محمد');
      expect(extractAskNameHint('كم حساب محمد'), 'محمد');
    });

    test('does not chop names that start with و ل ب ف', () {
      expect(extractAskNameHint('كم متبقي دين على وليد'), 'وليد');
      expect(extractAskNameHint('كم على وليد'), 'وليد');
      expect(extractAskNameHint('كم رصيد ليلى'), 'ليلى');
      expect(extractAskNameHint('كم دين فهد'), 'فهد');
      expect(extractAskNameHint('كم على بدر'), 'بدر');
      expect(extractAskNameHint('كم رصيد فاطمة'), 'فاطمة');
    });

    test('does not substring-strip على inside a name', () {
      expect(extractAskNameHint('كم رصيد عبدالعلى'), 'عبدالعلى');
    });

    test('leaves glued preposition for resolver retry', () {
      expect(extractAskNameHint('لمحمد'), 'لمحمد');
    });

    test('pronoun leftover is empty', () {
      expect(extractAskNameHint('What was his last payment amount?'), isNull);
      expect(isAskPronounHint('What was his last payment amount?'), isTrue);
    });
  });
}
