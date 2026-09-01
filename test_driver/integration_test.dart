import 'package:integration_test/integration_test_driver.dart';

/// Standard integration test driver.
///
/// Run with:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/ui_scroll_benchmark_test.dart \
///     --profile \
///     -d `DEVICE_ID`
Future<void> main() => integrationDriver();
