import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  FutureOr<void> build() {}

  Future<bool> complete() async {
    state = const AsyncLoading();
    final result = await ref.read(completeOnboardingUseCaseProvider).call();
    if (!ref.mounted) {
      return result.fold((_) => false, (_) => true);
    }
    return result.fold(
      (failure) {
        if (ref.mounted) {
          state = AsyncError(failure, StackTrace.current);
        }
        return false;
      },
      (_) {
        if (ref.mounted) {
          state = const AsyncData(null);
        }
        return true;
      },
    );
  }
}
