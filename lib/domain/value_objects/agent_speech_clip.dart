import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// In-memory Chirp 3 HD (or other) clip for one agent utterance.
///
/// Bytes stay off logs and Crashlytics.
class AgentSpeechClip extends Equatable {
  /// Creates a clip.
  const AgentSpeechClip({
    required this.bytes,
    this.mimeType = 'audio/mpeg',
  });

  /// MP3 payload. Never logged.
  final Uint8List bytes;

  /// MIME for playback (`audio/mpeg`).
  final String mimeType;

  /// Whether this clip can be played.
  bool get isNotEmpty => bytes.isNotEmpty;

  @override
  List<Object?> get props => [bytes, mimeType];
}
