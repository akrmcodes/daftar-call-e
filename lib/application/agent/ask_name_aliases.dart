import 'package:daftar/core/extensions/string_extensions.dart';

/// Closed MENA given-name aliases for ask-the-books FTS retries only.
///
/// Does not change global contact FTS. Scripts and Latin spellings in the
/// same group are tried until a unique Drift hit is found.
const _groups = <Set<String>>[
  {'mohammed', 'mohamed', 'muhammad', 'mohammad', 'محمد'},
  {'ahmed', 'ahmad', 'احمد'},
  {'ali', 'aly', 'علي'},
  {'hassan', 'hasan', 'حسن'},
  {'hussein', 'hussain', 'حسين'},
  {'omar', 'umar', 'عمر'},
  {'khaled', 'khalid', 'خالد'},
  {'yousef', 'youssef', 'yusuf', 'يوسف'},
  {'ibrahim', 'ebraheem', 'ابراهيم'},
  {'saleh', 'salih', 'صالح'},
  {'nasser', 'nasir', 'ناصر'},
  {'sami', 'سامي'},
  {'fatima', 'fatimah', 'فاطمه'},
  {'aisha', 'aesha', 'عائشه'},
];

/// Alternate search tokens for [hint], excluding [hint] itself.
List<String> askNameAliases(String hint) {
  final key = hint.trim().normalizeArabic().toLowerCase();
  if (key.isEmpty) {
    return const [];
  }
  for (final group in _groups) {
    final normalized = {
      for (final name in group) name.normalizeArabic().toLowerCase(),
    };
    if (!normalized.contains(key)) {
      continue;
    }
    return [
      for (final name in group)
        if (name.normalizeArabic().toLowerCase() != key) name,
    ];
  }
  return const [];
}
