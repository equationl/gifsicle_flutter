import 'dart:io';
import 'dart:convert';
import 'package:gifsicle_flutter/gifsicle_flutter.dart';

Future<void> main() async {
  final rows = <Map<String, Object>>[];
  try {
    for (final name in ['small-animation', 'large-canvas', 'many-frames']) {
      final bytes = await File('test/fixtures/$name.gif').readAsBytes();
      await Gifsicle.transformBytes(bytes);
      final watch = Stopwatch()..start();
      final result = await Gifsicle.transformBytes(bytes);
      watch.stop();
      rows.add({
        'fixture': name,
        'wallMicroseconds': watch.elapsedMicroseconds,
        'workerMicroseconds': result.elapsed.inMicroseconds,
        'outsideWorkerMicroseconds':
            watch.elapsedMicroseconds - result.elapsed.inMicroseconds,
        'inputBytes': bytes.length,
        'outputBytes': result.outputSize,
      });
    }
    await File(
      'tool/reports/dart_benchmark.json',
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(rows)}\n');
    print(const JsonEncoder.withIndent('  ').convert(rows));
  } finally {
    await Gifsicle.disposeForTesting();
  }
}
