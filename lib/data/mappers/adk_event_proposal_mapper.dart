import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';

/// Thrown when an ADK tool envelope cannot be mapped to [AgentProposal].
class ProposalParseException implements Exception {
  /// Creates a parse exception.
  const ProposalParseException(this.message, {this.code});

  /// Engineering diagnostic (never shown to merchants).
  final String message;

  /// Machine-readable code for Failure.code.
  final String? code;

  @override
  String toString() => 'ProposalParseException: $message';
}

/// Extracts Appendix J proposals from an ADK `/run` event list.
///
/// Mirrors `agent/scripts/smoke_1_4.py` (`extract_function_responses` +
/// `proposals_from_responses`). Money fields must be Dart [int] — never
/// `double`, `String`, or other [num] subtypes.
List<AgentProposal> extractProposalsFromAdkEvents(Object? events) {
  final out = <AgentProposal>[];
  for (final response in extractFunctionResponses(events)) {
    final envelope = _proposalEnvelope(response['response']);
    if (envelope == null) {
      continue;
    }
    out.add(parseAgentProposal(envelope));
  }
  return out;
}

/// Walks ADK events for `content.parts[].functionResponse`.
List<Map<String, Object?>> extractFunctionResponses(Object? events) {
  final found = <Map<String, Object?>>[];
  if (events is! List<dynamic>) {
    return found;
  }
  for (final event in events) {
    if (event is! Map) {
      continue;
    }
    final content = event['content'];
    if (content is! Map) {
      continue;
    }
    final parts = content['parts'];
    if (parts is! List<dynamic>) {
      continue;
    }
    for (final part in parts) {
      if (part is! Map) {
        continue;
      }
      final functionResponse = part['functionResponse'];
      if (functionResponse is Map) {
        found.add(Map<String, Object?>.from(functionResponse));
      }
    }
  }
  return found;
}

/// Optional assistant prose from model text parts (non-authoritative).
String? extractNarrativeFromAdkEvents(Object? events) {
  if (events is! List<dynamic>) {
    return null;
  }
  final buffer = StringBuffer();
  for (final event in events) {
    if (event is! Map) {
      continue;
    }
    final content = event['content'];
    if (content is! Map) {
      continue;
    }
    if (content['role'] != 'model') {
      continue;
    }
    final parts = content['parts'];
    if (parts is! List<dynamic>) {
      continue;
    }
    for (final part in parts) {
      if (part is! Map) {
        continue;
      }
      if (part.containsKey('functionCall') ||
          part.containsKey('functionResponse')) {
        continue;
      }
      final text = part['text'];
      if (text is String && text.trim().isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.write('\n');
        }
        buffer.write(text.trim());
      }
    }
  }
  final narrative = buffer.toString();
  return narrative.isEmpty ? null : narrative;
}

/// Parses one `{proposalId, tool, payload, confirmRequired}` envelope.
AgentProposal parseAgentProposal(Map<String, Object?> envelope) {
  final proposalId = envelope['proposalId'];
  final toolName = envelope['tool'];
  final payloadRaw = envelope['payload'];
  final confirmRequired = envelope['confirmRequired'];

  if (proposalId is! String || proposalId.isEmpty) {
    throw const ProposalParseException(
      'proposalId must be a non-empty string.',
      code: 'invalid_proposal_id',
    );
  }
  if (toolName is! String || toolName.isEmpty) {
    throw const ProposalParseException(
      'tool must be a non-empty string.',
      code: 'invalid_proposal_tool',
    );
  }
  final tool = ProposalTool.fromWireName(toolName);
  if (tool == null) {
    throw ProposalParseException(
      'Unknown proposal tool: $toolName',
      code: 'unknown_proposal_tool',
    );
  }
  if (payloadRaw is! Map) {
    throw const ProposalParseException(
      'payload must be an object.',
      code: 'invalid_proposal_payload',
    );
  }
  if (confirmRequired is! bool) {
    throw const ProposalParseException(
      'confirmRequired must be a boolean.',
      code: 'invalid_confirm_required',
    );
  }

  final payloadMap = Map<String, Object?>.from(payloadRaw);
  return AgentProposal(
    proposalId: proposalId,
    tool: tool,
    payload: parseProposalPayload(tool, payloadMap),
    confirmRequired: confirmRequired,
    rawEnvelope: Map<String, Object?>.from(envelope),
  );
}

/// Maps a tool payload object, enforcing integer `amountMinor` on money tools.
AgentProposalPayload parseProposalPayload(
  ProposalTool tool,
  Map<String, Object?> payload,
) {
  switch (tool) {
    case ProposalTool.proposeDebt:
      return AgentProposalPayload.debt(
        contactHint: _requireString(payload['contactHint'], 'contactHint'),
        amountMinor: _requireIntMinor(payload['amountMinor']),
        currencyCode: _requireString(payload['currencyCode'], 'currencyCode'),
        contactId: _optionalString(payload['contactId']),
        note: _optionalString(payload['note']),
        itemName: _optionalString(payload['itemName']),
        ledgerId: _optionalString(payload['ledgerId']),
        ledgerHint: _optionalString(payload['ledgerHint']),
      );
    case ProposalTool.proposePayment:
      return AgentProposalPayload.payment(
        contactHint: _requireString(payload['contactHint'], 'contactHint'),
        amountMinor: _requireIntMinor(payload['amountMinor']),
        currencyCode: _requireString(payload['currencyCode'], 'currencyCode'),
        contactId: _optionalString(payload['contactId']),
        note: _optionalString(payload['note']),
        itemName: _optionalString(payload['itemName']),
        ledgerId: _optionalString(payload['ledgerId']),
        ledgerHint: _optionalString(payload['ledgerHint']),
      );
    case ProposalTool.proposeCreateContact:
      return AgentProposalPayload.createContact(
        name: _requireString(payload['name'], 'name'),
        phone: _optionalString(payload['phone']),
        ledgerId: _optionalString(payload['ledgerId']),
      );
    case ProposalTool.proposeCreateLedger:
      return AgentProposalPayload.createLedger(
        name: _requireString(payload['name'], 'name'),
        type: _optionalString(payload['type']),
      );
    case ProposalTool.proposeClosingPlan:
      return AgentProposalPayload.closingPlan(
        steps: _closingPlanSteps(payload['steps']),
        localDay: _optionalString(payload['localDay']),
      );
    case ProposalTool.parseGoal:
      return AgentProposalPayload.parseGoal(
        goalClass: _requireString(payload['goalClass'], 'goalClass'),
        confidence: _optionalDouble(payload['confidence']),
        notes: _optionalString(payload['notes']),
      );
    case ProposalTool.proposeStatement:
      return AgentProposalPayload.statement(
        contactId: _optionalString(payload['contactId']) ?? '',
        contactHint: _optionalString(payload['contactHint']),
        ledgerId: _optionalString(payload['ledgerId']),
      );
    case ProposalTool.proposeWhatsappDrafts:
      return AgentProposalPayload.generic(json: payload);
  }
}

Map<String, Object?>? _proposalEnvelope(Object? response) {
  if (_isProposalMap(response)) {
    return Map<String, Object?>.from(response! as Map);
  }
  if (response is Map && _isProposalMap(response['result'])) {
    return Map<String, Object?>.from(response['result'] as Map);
  }
  return null;
}

bool _isProposalMap(Object? value) {
  if (value is! Map) {
    return false;
  }
  return value['proposalId'] is String &&
      value['tool'] is String &&
      value['payload'] is Map &&
      value.containsKey('confirmRequired');
}

String _requireString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw ProposalParseException(
    '$field must be a non-empty string.',
    code: 'invalid_proposal_payload',
  );
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _requireIntMinor(Object? value) {
  if (value is int) {
    return value;
  }
  throw ProposalParseException(
    'amountMinor must be an integer (got ${value.runtimeType}).',
    code: 'invalid_amount_minor',
  );
}

double? _optionalDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return null;
}

List<ClosingPlanStep> _closingPlanSteps(Object? value) {
  if (value is! List<dynamic> || value.isEmpty) {
    throw const ProposalParseException(
      'closing plan steps must be a non-empty array.',
      code: 'invalid_proposal_payload',
    );
  }
  final steps = <ClosingPlanStep>[];
  for (final item in value) {
    if (item is! Map) {
      throw const ProposalParseException(
        'closing plan step must be an object.',
        code: 'invalid_proposal_payload',
      );
    }
    steps.add(
      ClosingPlanStep(
        title: _requireString(item['title'], 'title'),
        tool: _optionalString(item['tool']),
        notes: _optionalString(item['notes']),
      ),
    );
  }
  return steps;
}
