import 'package:daftar/application/agent/arabic_name_particles.dart';

/// Device classifier for Closing Agent ask-the-books goals.
enum AskBooksIntent {
  /// Who still owes / overdue list.
  overdueList,

  /// Rank outstanding by size, highest first.
  largestOutstanding,

  /// Rank outstanding by size, lowest first.
  smallestOutstanding,

  /// Named contact current balance.
  namedBalance,

  /// Named contact latest payment.
  lastPayment,

  /// Named contact latest debt.
  lastDebt,
}

final _digit = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');

const _lastPaymentEn = <String>[
  'last payment',
  'last paid',
  'latest payment',
  'what did he pay',
  'what did she pay',
  'what did they pay',
];

const _lastPaymentAr = <String>[
  'آخر دفعة',
  'اخر دفعة',
  'آخر سداد',
  'اخر سداد',
  'آخر دفعة له',
  'كم سدد آخر مرة',
];

const _lastDebtEn = <String>[
  'last debt',
  'last purchase',
];

const _lastDebtAr = <String>[
  'آخر دين',
  'اخر دين',
  'آخر قيد',
  'اخر قيد',
];

const _largestEn = <String>[
  'largest outstanding',
  'largest debt',
  'biggest debt',
  'highest debt',
  'who owes the most',
  'who has a large',
];

const _largestAr = <String>[
  'أكبر دين',
  'اكبر دين',
  'أكبر مديونية',
  'اكبر مديونية',
  'من عليه أكثر',
  'من عليه اكثر',
  'من عليه اكبر',
  'من عليه أكبر',
  'أعلى دين',
  'اعلى دين',
];

const _smallestEn = <String>[
  'smallest outstanding',
  'smallest debt',
  'lowest debt',
  'least debt',
  'who owes the least',
];

const _smallestAr = <String>[
  'أقل دين',
  'اقل دين',
  'أصغر دين',
  'اصغر دين',
  'من عليه أقل',
  'من عليه اقل',
  'أدنى دين',
  'ادنى دين',
  'صاحب أقل',
  'صاحب اقل',
];

const _overdueEn = <String>[
  "who hasn't paid",
  'who hasnt paid',
  'who have not paid',
  'who is overdue',
  'late on payments',
  'who still owes',
  'overdue',
  'unpaid',
];

const _overdueAr = <String>[
  'من ما سدد',
  'من لم يسدد',
  'المتأخرين',
  'المتأخرون',
  'من لم يدفع',
  'اللي ما سددوا',
];

const _namedEn = <String>[
  'how much debt',
  'how much does',
  'how much do',
  "what's",
  'whats ',
  'what is',
  'still owes',
  'still owe',
  'left to pay',
  'remaining',
  'outstanding',
  'balance',
  'owed',
];

const _namedAr = <String>[
  'كم متبقي',
  'كم متبقى',
  'كم حساب',
  'كم على',
  'كم عليه',
  'كم دين',
  'كم باقي',
  'كم تبقى',
  'ما تبقى',
  'ما بقي',
  'ما عليه',
  'قديش عليه',
  'قده عليه',
  'عليه كام',
  'كام عليه',
  'شقد عليه',
  'المتبقي',
  'المتبقى',
  'متبقي',
  'متبقى',
  'رصيد',
];

const _stripEn = <String>[
  'how much did',
  'how much',
  'what was',
  'what were',
  'account',
  'customer',
  'currently',
  'outstanding',
  'remaining',
  'amount',
  'payment',
  'paid',
  'debt',
  'still',
];

const _stripAr = <String>[
  'حساب',
  'زبون',
  'دين',
  'دفعة',
  'سداد',
  'المتبقي',
  'المتبقى',
  'متبقي',
  'متبقى',
  'باقي',
  'تبقى',
  'صاحب',
  'عليه',
  'لها',
  'مازال',
  'لسه',
  'على',
  'كم',
];

const _enStop = <String>[
  'does',
  'do',
  'did',
  'the',
  'for',
  'of',
  'owe',
  'owes',
  'owed',
  'my',
  'me',
  'a',
  'an',
  'was',
  'were',
  'and',
  'to',
  'pay',
];

const _pronouns = <String>{
  'his',
  'her',
  'their',
  'him',
  'he',
  'she',
  'they',
  'this',
  'that',
  'له',
  'لها',
  'عليه',
  'عليها',
  'حسابه',
  'هذا',
  'هذه',
  'هذي',
  'ذاك',
  'ذلك',
};

/// Classifies [goalText] as an ask intent, or null for capture / other.
AskBooksIntent? classifyAsk(String goalText) {
  final trimmed = goalText.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (_matches(_lastPaymentEn, _lastPaymentAr, trimmed) ||
      _howMuchDidPay(trimmed)) {
    return _digit.hasMatch(trimmed) ? null : AskBooksIntent.lastPayment;
  }
  if (_matches(_lastDebtEn, _lastDebtAr, trimmed)) {
    return _digit.hasMatch(trimmed) ? null : AskBooksIntent.lastDebt;
  }
  if (_matches(_largestEn, _largestAr, trimmed)) {
    return _digit.hasMatch(trimmed) ? null : AskBooksIntent.largestOutstanding;
  }
  if (_matches(_smallestEn, _smallestAr, trimmed)) {
    return _digit.hasMatch(trimmed) ? null : AskBooksIntent.smallestOutstanding;
  }
  if (_matches(_overdueEn, _overdueAr, trimmed)) {
    return AskBooksIntent.overdueList;
  }
  if (_digit.hasMatch(trimmed)) {
    return null;
  }
  if (_matches(_namedEn, _namedAr, trimmed)) {
    return AskBooksIntent.namedBalance;
  }
  return null;
}

/// Name leftover after stripping ask phrasing, or null if none / pronoun.
///
/// Drops phrases as whole tokens. Does not strip leading `و`/`ل`/`ب`/`ف`.
String? extractAskNameHint(String goalText) {
  final trimmed = goalText.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final phrases = <String>[
    ..._lastPaymentEn,
    ..._lastPaymentAr,
    ..._lastDebtEn,
    ..._lastDebtAr,
    ..._largestEn,
    ..._largestAr,
    ..._smallestEn,
    ..._smallestAr,
    ..._overdueEn,
    ..._overdueAr,
    ..._namedEn,
    ..._namedAr,
    ..._stripEn,
    ..._stripAr,
    ..._enStop,
  ];
  final kept = [
    for (final token in leftoverNameTokens(trimmed, phrases))
      if (token.isNotEmpty && !_isPronounToken(token)) token,
  ];
  if (kept.isEmpty) {
    return null;
  }
  return kept.join(' ');
}

/// Whether leftover text is only a pronoun (use lastAskContactId).
bool isAskPronounHint(String goalText) {
  if (extractAskNameHint(goalText) != null) {
    return false;
  }
  final rest = goalText.trim().toLowerCase();
  if (rest.isEmpty) {
    return false;
  }
  for (final pronoun in _pronouns) {
    if (rest.contains(pronoun)) {
      return true;
    }
  }
  return false;
}

bool _matches(List<String> en, List<String> ar, String text) {
  final lower = text.toLowerCase();
  for (final phrase in en) {
    if (lower.contains(phrase)) {
      return true;
    }
  }
  for (final phrase in ar) {
    if (text.contains(phrase)) {
      return true;
    }
  }
  return false;
}

bool _howMuchDidPay(String text) {
  final lower = text.toLowerCase();
  if (!lower.contains('how much did')) {
    return false;
  }
  return lower.contains('pay') || lower.contains('paid');
}

bool _isPronounToken(String token) {
  return _pronouns.contains(token.toLowerCase());
}
