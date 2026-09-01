// Query-side Arabic given-name particle helpers (ask/statement only).
// Does not change the global FTS5 tokenizer. `عبد الله` and `عبدالله` are
// the same theophoric name; FTS AND on three tokens fails against two.
final _abdPrefix = RegExp(r'عبد\s+');
final _punct = RegExp('[?؟!,.،]');
const _glueLetters = {'ل', 'ب', 'و', 'ف'};

/// Joins `عبد` to the following token (`أحمد عبد الله` → `أحمد عبدالله`).
String collapseAbdParticles(String hint) {
  return hint.trim().replaceAll(_abdPrefix, 'عبد');
}

/// Splits a glued `عبد…` token (`عبدالله` → `عبد الله`).
String expandAbdParticles(String hint) {
  final tokens = hint.trim().split(RegExp(r'\s+'));
  final expanded = <String>[];
  for (final token in tokens) {
    if (token.startsWith('عبد') && token.length > 3) {
      expanded
        ..add('عبد')
        ..add(token.substring(3));
    } else {
      expanded.add(token);
    }
  }
  return expanded.join(' ');
}

/// Strips a leading Arabic preposition or article from a single token.
///
/// Use only as a **zero-hit FTS retry**. Never apply during name extract —
/// that turns `وليد` into `ليد`.
String stripArabicNamePrefix(String token) {
  if (token.startsWith('ال') && token.length > 2) {
    return token.substring(2);
  }
  if (token.length > 2 &&
      (token.startsWith('ل') ||
          token.startsWith('ب') ||
          token.startsWith('و') ||
          token.startsWith('ف'))) {
    return token.substring(1);
  }
  return token;
}

/// First-token prefix strip, remainder kept. Null when the hint is unchanged.
String? stripFirstTokenPrefix(String hint) {
  final parts = hint.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return null;
  }
  final stripped = stripArabicNamePrefix(parts.first);
  if (stripped.isEmpty || stripped == parts.first) {
    return null;
  }
  if (parts.length == 1) {
    return stripped;
  }
  return '$stripped ${parts.skip(1).join(' ')}';
}

/// Drops [phrases] as whole token sequences (longest first).
///
/// A phrase whose last token is a single letter `ل`/`ب`/`و`/`ف` also matches
/// when that letter is glued to the following name (`كشف حساب لوليد` → `وليد`).
/// Does not strip name prefixes. Shared by ask and statement extract.
List<String> leftoverNameTokens(String text, List<String> phrases) {
  final tokens = text
      .trim()
      .replaceAll(_punct, ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) {
    return const [];
  }

  final phraseLists = <List<String>>[
    for (final phrase in phrases)
      phrase
          .trim()
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList(),
  ]
    ..removeWhere((parts) => parts.isEmpty)
    ..sort((left, right) {
      final byCount = right.length.compareTo(left.length);
      if (byCount != 0) {
        return byCount;
      }
      return right.join().length.compareTo(left.join().length);
    });

  final kept = <String>[];
  var i = 0;
  while (i < tokens.length) {
    var skip = 0;
    String? gluedRemainder;
    for (final phrase in phraseLists) {
      final n = phrase.length;
      if (i + n > tokens.length) {
        continue;
      }
      if (!_headTokensMatch(tokens, i, phrase, n - 1)) {
        continue;
      }
      final lastPhrase = phrase.last;
      final lastSource = tokens[i + n - 1];
      if (_tokenEquals(lastSource, lastPhrase)) {
        skip = n;
        break;
      }
      if (lastPhrase.length == 1 &&
          _glueLetters.contains(lastPhrase) &&
          lastSource.startsWith(lastPhrase) &&
          lastSource.length > lastPhrase.length) {
        skip = n;
        gluedRemainder = lastSource.substring(lastPhrase.length);
        break;
      }
    }
    if (skip > 0) {
      i += skip;
      if (gluedRemainder != null) {
        final cleaned = _stripPossessive(gluedRemainder);
        if (cleaned.isNotEmpty) {
          kept.add(cleaned);
        }
      }
      continue;
    }
    final cleaned = _stripPossessive(tokens[i]);
    if (cleaned.isNotEmpty) {
      kept.add(cleaned);
    }
    i += 1;
  }
  return kept;
}

bool _headTokensMatch(
  List<String> tokens,
  int start,
  List<String> phrase,
  int count,
) {
  for (var k = 0; k < count; k++) {
    if (!_tokenEquals(tokens[start + k], phrase[k])) {
      return false;
    }
  }
  return true;
}

bool _tokenEquals(String left, String right) {
  return _foldToken(left) == _foldToken(right);
}

String _foldToken(String token) {
  return token.replaceAll('’', "'").toLowerCase();
}

String _stripPossessive(String token) {
  final folded = token.replaceAll('’', "'");
  if (folded.length > 2 && folded.toLowerCase().endsWith("'s")) {
    return folded.substring(0, folded.length - 2);
  }
  return folded;
}
