import 'package:daftar/application/agent/arabic_name_particles.dart';
import 'package:daftar/application/agent/ask_name_aliases.dart';
import 'package:daftar/application/contact/search_contacts_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:fpdart/fpdart.dart';

/// Resolves a spoken/typed name hint against Drift FTS with Arabic retries.
///
/// Retries only when the previous query returned zero hits. Does not change
/// global contact FTS tokenization.
class ResolveContactHintUseCase {
  /// Creates the use case.
  const ResolveContactHintUseCase({
    required SearchContactsUseCase searchContactsUseCase,
  }) : _searchContactsUseCase = searchContactsUseCase;

  final SearchContactsUseCase _searchContactsUseCase;

  /// FTS [hint], then collapse/expand `عبد`, prefix-strip first token,
  /// first token, then closed aliases. Prefix-strip is a zero-hit retry only.
  Future<Either<Failure, List<ContactSearchHit>>> execute(String hint) async {
    final trimmed = hint.trim();
    if (trimmed.isEmpty) {
      return const Right(<ContactSearchHit>[]);
    }

    final seen = <String>{};
    for (final query in _queries(trimmed)) {
      if (!seen.add(query)) {
        continue;
      }
      final result = await _search(query);
      if (result.isLeft()) {
        return Left(result.getLeft().toNullable()!);
      }
      final hits =
          result.getRight().toNullable() ?? const <ContactSearchHit>[];
      if (hits.isNotEmpty) {
        return Right(hits);
      }
    }
    return const Right(<ContactSearchHit>[]);
  }

  List<String> _queries(String hint) {
    final collapsed = collapseAbdParticles(hint);
    final expanded = expandAbdParticles(hint);
    final token = hint.split(RegExp(r'\s+')).first;
    final stripped = stripFirstTokenPrefix(hint);
    final queries = <String>[hint, collapsed, expanded];
    if (stripped != null) {
      queries.add(stripped);
    }
    if (token != hint) {
      queries.add(token);
    }
    queries.addAll(askNameAliases(token));
    return queries;
  }

  Future<Either<Failure, List<ContactSearchHit>>> _search(String query) {
    return _searchContactsUseCase.execute(
      query,
      excludeUserArchivedLedgers: true,
    );
  }
}
