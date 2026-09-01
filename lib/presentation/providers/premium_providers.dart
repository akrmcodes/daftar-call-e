import 'package:daftar/application/activation/activate_code_use_case.dart';
import 'package:daftar/domain/entities/activation_status.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/screens/premium/widgets/activation_code_formatter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'premium_providers.g.dart';

/// Activation summary for plan-status UI (null when on free tier).
@Riverpod(keepAlive: true)
Future<ActivationStatus?> activationStatus(Ref ref) async {
  final result = await ref.read(activationRepositoryProvider).getStatus();
  return result.fold((_) => null, (status) => status);
}

/// Redeems an activation code via [ActivateCodeUseCase].
@Riverpod(keepAlive: true)
class ActivateCodeController extends _$ActivateCodeController {
  @override
  FutureOr<void> build() {}

  /// Returns `true` when activation succeeded.
  Future<bool> activate(String formattedCode) async {
    state = const AsyncLoading();
    final code = ActivationCodeInput.normalize(formattedCode);
    final result = await ref.read(activateCodeUseCaseProvider).call(code);
    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) async {
        await ref
            .read(entitlementControllerProvider.notifier)
            .refreshAfterActivation();
        ref
          ..invalidate(activationStatusProvider)
          ..invalidate(entitlementProvider);
        state = const AsyncData(null);
        return true;
      },
    );
  }

  void reset() {
    state = const AsyncData(null);
  }
}
