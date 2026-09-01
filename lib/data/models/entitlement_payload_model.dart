import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/domain/enums/feature_flag.dart';

/// JSON-serializable entitlement payload embedded in signed tokens.
class EntitlementPayloadModel {
  const EntitlementPayloadModel({
    required this.schemaVersion,
    required this.tier,
    required this.features,
    required this.maxLedgers,
    required this.maxContacts,
    required this.maxTransactions,
    this.expiresAt,
    this.issuedAt,
  });

  factory EntitlementPayloadModel.fromEntitlement(Entitlement entitlement) {
    return EntitlementPayloadModel(
      schemaVersion: 1,
      tier: entitlement.tier,
      features: entitlement.activeFeatures.toList(),
      maxLedgers: entitlement.maxLedgers,
      maxContacts: entitlement.maxContacts,
      maxTransactions: entitlement.maxTransactions,
      expiresAt: entitlement.expiryDate,
      issuedAt: DateTime.now().toUtc(),
    );
  }

  factory EntitlementPayloadModel.fromJson(Map<String, dynamic> json) {
    return EntitlementPayloadModel(
      schemaVersion: json['v'] as int? ?? 1,
      tier: _tierFromString(json['tier'] as String? ?? 'free'),
      features: _featuresFromJson(json['features']),
      maxLedgers: json['maxLedgers'] as int? ?? 1,
      maxContacts: json['maxContacts'] as int? ?? 50,
      maxTransactions: json['maxTransactions'] as int? ?? 500,
      expiresAt: _parseDate(json['exp']),
      issuedAt: _parseDate(json['iat']),
    );
  }

  final int schemaVersion;
  final AppTier tier;
  final List<FeatureFlag> features;
  final int maxLedgers;
  final int maxContacts;
  final int maxTransactions;
  final DateTime? expiresAt;
  final DateTime? issuedAt;

  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'tier': tier.name,
    'features': features.map((f) => f.name).toList(),
    'maxLedgers': maxLedgers,
    'maxContacts': maxContacts,
    'maxTransactions': maxTransactions,
    if (expiresAt != null) 'exp': expiresAt!.toUtc().toIso8601String(),
    if (issuedAt != null) 'iat': issuedAt!.toUtc().toIso8601String(),
  };

  Entitlement toDomain() => Entitlement(
    tier: tier,
    activeFeatures: features.toSet(),
    maxLedgers: maxLedgers,
    maxContacts: maxContacts,
    maxTransactions: maxTransactions,
    expiryDate: expiresAt,
  );

  static AppTier _tierFromString(String raw) {
    return switch (raw.toLowerCase()) {
      'pro' => AppTier.pro,
      'proplus' || 'pro_plus' || 'pro+' => AppTier.proPlus,
      _ => AppTier.free,
    };
  }

  static List<FeatureFlag> _featuresFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final flags = <FeatureFlag>[];
    for (final name in raw.whereType<String>()) {
      for (final flag in FeatureFlag.values) {
        if (flag.name == name) {
          flags.add(flag);
          break;
        }
      }
    }
    return flags;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }
}
