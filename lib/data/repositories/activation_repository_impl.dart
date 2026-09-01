import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/dev/dev_entitlement.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/activation_secure_storage_ds.dart';
import 'package:daftar/data/datasources/remote/activation_api_ds.dart';
import 'package:daftar/data/services/entitlement_payload_codec.dart';
import 'package:daftar/data/services/offline_activation_validator.dart';
import 'package:daftar/domain/entities/activation_status.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Secure entitlement engine: online JWT from Edge Function, offline fallback.
class ActivationRepositoryImpl implements ActivationRepository {
  ActivationRepositoryImpl({
    required ActivationApiDs activationApiDs,
    required ActivationSecureStorageDs secureStorageDs,
    EntitlementPayloadCodec? codec,
  }) : _activationApiDs = activationApiDs,
       _secureStorageDs = secureStorageDs,
       _codec = codec ?? EntitlementPayloadCodec();

  final ActivationApiDs _activationApiDs;
  final ActivationSecureStorageDs _secureStorageDs;
  final EntitlementPayloadCodec _codec;

  @override
  Future<Either<Failure, Entitlement>> activate(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Left(
        AuthFailure('Activation code is required.', code: 'empty_code'),
      );
    }

    String? token;
    Entitlement? entitlement;

    try {
      token = await _activationApiDs.activate(code: trimmed);
      entitlement = _codec.decode(token);
      if (entitlement == null) {
        return const Left(
          AuthFailure(
            'Server returned an invalid entitlement token.',
            code: 'invalid_token',
          ),
        );
      }
    } on ServerException {
      final tier = OfflineActivationValidator.validateTier(trimmed);
      if (tier == null) {
        return const Left(
          AuthFailure(
            'Invalid activation code. Check the code and try again when online.',
            code: 'invalid_offline_code',
          ),
        );
      }
      entitlement = offlineEntitlementForTier(tier);
      token = _codec.encodeOffline(entitlement);
    } on Object catch (e) {
      return Left(
        AuthFailure('Activation failed: $e', code: 'activation_error'),
      );
    }

    try {
      await _secureStorageDs.writeToken(token);
    } on Object catch (e) {
      return Left(
        StorageFailure(
          'Failed to store entitlement token: $e',
          code: 'secure_storage_write',
        ),
      );
    }

    return Right(entitlement.effective);
  }

  @override
  Future<Entitlement> getEntitlement() async {
    if (DevEntitlement.forceProPlusInDevelopment) {
      return DevEntitlement.developmentProPlus();
    }

    try {
      final token = await _secureStorageDs.readToken();
      if (token == null || token.isEmpty) {
        return Entitlement.defaultFree();
      }
      final decoded = _codec.decode(token);
      if (decoded == null) {
        return Entitlement.defaultFree();
      }
      return decoded.effective;
    } on Object {
      return Entitlement.defaultFree();
    }
  }

  @override
  Future<Either<Failure, ActivationStatus?>> getStatus() async {
    if (DevEntitlement.forceProPlusInDevelopment) {
      final entitlement = DevEntitlement.developmentProPlus();
      final expiry = entitlement.expiryDate;
      return Right(
        ActivationStatus(
          tier: entitlement.tier,
          expiresAt: expiry,
          daysRemaining: expiry
              ?.toUtc()
              .difference(DateTime.now().toUtc())
              .inDays,
        ),
      );
    }

    try {
      final entitlement = await getEntitlement();
      if (entitlement.tier == AppTier.free) {
        return const Right(null);
      }
      final expiry = entitlement.expiryDate;
      int? daysRemaining;
      if (expiry != null) {
        daysRemaining = expiry.toUtc().difference(DateTime.now().toUtc()).inDays;
        if (daysRemaining < 0) {
          daysRemaining = 0;
        }
      }
      return Right(
        ActivationStatus(
          tier: entitlement.tier,
          expiresAt: expiry,
          daysRemaining: daysRemaining,
        ),
      );
    } on Object catch (e) {
      return Left(
        StorageFailure('Failed to read activation status: $e'),
      );
    }
  }

  @override
  Future<bool> isFeatureUnlocked(FeatureFlag feature) async {
    final entitlement = await getEntitlement();
    return entitlement.hasFeature(feature);
  }

  @override
  Future<bool> isFeatureKeyUnlocked(String featureKey) async {
    final entitlement = await getEntitlement();
    return switch (featureKey) {
      AppConstants.featureUnlimitedLedgers => entitlement.hasUnlimitedLedgers,
      AppConstants.featureUnlimitedContacts => entitlement.hasUnlimitedContacts,
      AppConstants.featureUnlimitedTransactions =>
        entitlement.hasUnlimitedTransactions,
      AppConstants.featureWhatsappAutomation => entitlement.hasFeature(
        FeatureFlag.whatsappAutomation,
      ),
      'brandedPdf' => entitlement.hasFeature(FeatureFlag.brandedPdf),
      AppConstants.featureLedgerArchiving => entitlement.hasFeature(
        FeatureFlag.ledgerArchiving,
      ),
      'smartMerge' => entitlement.hasFeature(FeatureFlag.smartMerge),
      'multiDeviceSync' => entitlement.hasFeature(FeatureFlag.multiDeviceSync),
      'advancedAnalytics' => entitlement.hasFeature(
        FeatureFlag.advancedAnalytics,
      ),
      'customerPortal' => entitlement.hasFeature(FeatureFlag.customerPortal),
      AppConstants.featureCloudBackup => true,
      AppConstants.featureCsvImport => true,
      AppConstants.featureCreditLimits => true,
      _ => false,
    };
  }
}
