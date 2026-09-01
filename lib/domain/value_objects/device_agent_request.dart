import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_agent_request.freezed.dart';

/// Ledger id + display name for Appendix J.2 `ledgers`.
@freezed
abstract class AgentLedgerRef with _$AgentLedgerRef {
  const factory AgentLedgerRef({
    required String id,
    required String name,
  }) = _AgentLedgerRef;
}

/// Voice / search hint for Appendix J.2 `voiceHints`.
@freezed
abstract class AgentVoiceHint with _$AgentVoiceHint {
  const factory AgentVoiceHint({
    required String displayName,
    String? contactId,
    String? phone,
  }) = _AgentVoiceHint;
}

/// Appendix J.2 request carried as `stateDelta.daftarContext`.
@freezed
abstract class DeviceAgentRequest with _$DeviceAgentRequest {
  const factory DeviceAgentRequest({
    required String correlationId,
    required String locale,
    required String merchantLocalDay,
    required List<AgentLedgerRef> ledgers,
    required List<AgentVoiceHint> voiceHints,
    required bool isMultiCurrencyEnabled,
    required String defaultCurrency,
    required String goalText,
    String? audioRef,
  }) = _DeviceAgentRequest;

  const DeviceAgentRequest._();

  /// JSON object matching `DeviceAgentRequest` in `agent/openapi.yaml`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'correlationId': correlationId,
      'locale': locale,
      'merchantLocalDay': merchantLocalDay,
      'ledgers': [
        for (final ledger in ledgers)
          <String, Object?>{'id': ledger.id, 'name': ledger.name},
      ],
      'voiceHints': [
        for (final hint in voiceHints)
          <String, Object?>{
            'displayName': hint.displayName,
            'contactId': hint.contactId,
            'phone': hint.phone,
          },
      ],
      'isMultiCurrencyEnabled': isMultiCurrencyEnabled,
      'defaultCurrency': defaultCurrency,
      'goalText': goalText,
      if (audioRef != null) 'audioRef': audioRef,
    };
  }
}
