import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    // Both suites must finish both tests; an empty run must never pass CI.
    if (data?['completedTests'] != 2) {
      throw StateError('Expected 2 completed tests, received $data');
    }
    await writeResponseData(data);
  },
);
