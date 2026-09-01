import 'package:daftar/application/agent/resolve_contact_hint_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:fpdart/fpdart.dart';

/// Lists Drift contacts matching a proposal name hint (archived ledgers excluded).
class ListAgentContactCandidatesUseCase {
  /// Creates the use case.
  const ListAgentContactCandidatesUseCase({
    required ResolveContactHintUseCase resolveContactHintUseCase,
  }) : _resolveContactHintUseCase = resolveContactHintUseCase;

  final ResolveContactHintUseCase _resolveContactHintUseCase;

  /// Returns FTS hits for [contactHint], or an empty list when the hint is blank.
  Future<Either<Failure, List<ContactSearchHit>>> execute({
    required String contactHint,
  }) async {
    final hint = contactHint.trim();
    if (hint.isEmpty) {
      return const Right(<ContactSearchHit>[]);
    }
    return _resolveContactHintUseCase.execute(hint);
  }
}
