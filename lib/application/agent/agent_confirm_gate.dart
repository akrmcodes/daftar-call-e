import 'package:daftar/core/errors/failures.dart';
import 'package:fpdart/fpdart.dart';

/// Process-local single-flight lock keyed by `proposalId` (Appendix J.5).
///
/// Dart is single-isolate: check-then-set without `await` is atomic.
class AgentConfirmGate {
  final Map<String, Object> _inFlight = {};

  /// Whether [proposalId] currently has an in-flight confirm.
  bool isInFlight(String proposalId) => _inFlight.containsKey(proposalId);

  /// Runs [action] exclusively for [proposalId].
  ///
  /// If another confirm is already running, returns [onInFlight] without
  /// starting a second action.
  Future<Either<Failure, T>> runExclusive<T>({
    required String proposalId,
    required Future<Either<Failure, T>> Function() action,
    required T Function() onInFlight,
  }) async {
    if (_inFlight.containsKey(proposalId)) {
      return Right(onInFlight());
    }

    late final Future<Either<Failure, T>> future;
    future = action();
    _inFlight[proposalId] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[proposalId], future)) {
        _inFlight.remove(proposalId);
      }
    }
  }
}
