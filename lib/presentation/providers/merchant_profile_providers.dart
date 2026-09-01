import 'package:daftar/application/merchant/clear_merchant_logo_use_case.dart';
import 'package:daftar/application/merchant/set_merchant_logo_use_case.dart';
import 'package:daftar/application/merchant/update_merchant_profile_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'merchant_profile_providers.g.dart';

/// Streams the singleton merchant profile from [MerchantProfileRepository].
@Riverpod(keepAlive: true)
Stream<MerchantProfile?> merchantProfile(Ref ref) {
  return ref.watch(merchantProfileRepositoryProvider).watch();
}

/// Mutation controller for merchant branding (profile fields and logo).
@Riverpod(keepAlive: true)
class MerchantProfileController extends _$MerchantProfileController {
  @override
  FutureOr<void> build() {}

  /// Persists store name and optional phone via [UpdateMerchantProfileUseCase].
  ///
  /// Sets [state] to loading, then error ([Failure]) or success. Returns the
  /// saved profile on success, or `null` when a failure occurred.
  Future<MerchantProfile?> updateProfile({
    required String storeName,
    String? storePhone,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(updateMerchantProfileUseCaseProvider)
        .execute(storeName: storeName, storePhone: storePhone);

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (profile) {
        state = const AsyncData(null);
        return profile;
      },
    );
  }

  /// Optimizes and stores a logo via [SetMerchantLogoUseCase].
  ///
  /// Sets [state] to loading, then error ([Failure]) or success. Returns the
  /// absolute logo path on success, or `null` when a failure occurred.
  Future<String?> setLogo({required String sourcePath}) async {
    state = const AsyncLoading();
    final result = await ref
        .read(setMerchantLogoUseCaseProvider)
        .execute(sourcePath: sourcePath);

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
      (logoPath) {
        state = const AsyncData(null);
        return logoPath;
      },
    );
  }

  /// Clears the stored logo via [ClearMerchantLogoUseCase].
  ///
  /// Sets [state] to loading, then error ([Failure]) or success. Returns `true`
  /// when the logo was removed.
  Future<bool> removeLogo() async {
    state = const AsyncLoading();
    final result =
        await ref.read(clearMerchantLogoUseCaseProvider).execute();

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Clears the controller mutation state after the UI handles feedback.
  void reset() {
    state = const AsyncData(null);
  }
}
