import 'package:daftar/application/auth/session_bootstrap_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:fpdart/fpdart.dart';

/// Single-flight cache for cold-start session bootstrap.
///
/// Ensures [SessionBootstrapUseCase.execute] runs at most once per process
/// unless [invalidate] is called (sign-in, sign-out, account switch).
class SessionBootstrapCoordinator {
  SessionBootstrapCoordinator(this._sessionBootstrapUseCase);

  final SessionBootstrapUseCase _sessionBootstrapUseCase;

  Either<Failure, AuthSessionState>? _cached;
  Future<Either<Failure, AuthSessionState>>? _inFlight;

  /// Runs bootstrap once, sharing the in-flight future across concurrent callers.
  Future<Either<Failure, AuthSessionState>> execute({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cached != null) {
      return _cached!;
    }
    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final future = _sessionBootstrapUseCase.execute().then((result) {
      _cached = result;
      return result;
    });

    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  /// Clears cached bootstrap state after auth mutations.
  void invalidate() {
    _cached = null;
    _inFlight = null;
  }
}
