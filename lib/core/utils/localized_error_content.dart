/// User-facing error copy resolved through the error translator.
class LocalizedErrorContent {
  const LocalizedErrorContent({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}
