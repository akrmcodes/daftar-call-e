import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:fpdart/fpdart.dart';

Either<Failure, Unit>? rejectIfUserArchived(Ledger ledger) {
  if (ledger.isUserArchived) {
    return const Left(
      ValidationFailure(
        'This ledger is archived and read-only.',
        code: 'ledger_archived',
      ),
    );
  }
  return null;
}
