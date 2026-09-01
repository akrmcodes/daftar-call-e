import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/value_objects/voice_entity_resolution_entry.dart';
import 'package:fpdart/fpdart.dart';

class GetActiveVoiceContextUseCase {
  const GetActiveVoiceContextUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  Future<Either<Failure, List<VoiceEntityResolutionEntry>>> execute() {
    return _contactRepository.getVoiceEntityResolutionContext();
  }
}
