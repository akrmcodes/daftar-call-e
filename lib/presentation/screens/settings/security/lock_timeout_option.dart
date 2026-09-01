/// Auto-lock timeout presets (seconds). `0` = immediately on resume.
abstract final class LockTimeoutOption {
  static const int immediately = 0;
  static const int oneMinute = 60;
  static const int fiveMinutes = 300;
  static const int fifteenMinutes = 900;

  static const List<int> values = [
    immediately,
    oneMinute,
    fiveMinutes,
    fifteenMinutes,
  ];
}
