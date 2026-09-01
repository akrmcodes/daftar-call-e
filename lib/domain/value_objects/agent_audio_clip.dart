import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// In-memory WAV (or other) clip for one Closing Agent `/run` turn.
///
/// Bytes stay off the device agent JSON payload — only a short `audioRef`
/// marker is sent in `daftarContext`.
class AgentAudioClip extends Equatable {
  /// Creates a clip.
  const AgentAudioClip({
    required this.bytes,
    this.mimeType = 'audio/wav',
  });

  /// PCM payload. Never logged.
  final Uint8List bytes;

  /// MIME for ADK `inlineData.mimeType`.
  final String mimeType;

  /// Whether this clip can be posted.
  bool get isNotEmpty => bytes.isNotEmpty;

  @override
  List<Object?> get props => [bytes, mimeType];
}
