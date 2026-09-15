import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/gif_comparison.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mac = base64Decode(
    'R0lGODlhAQABAHD/ACH5BAEKAP8ALAAAAAABAAEAAAgEAP8FBAAh+QQBCgD/ACwAAAAAAQABAAAIBAD/BQQAOw==',
  );
  final windows = base64Decode(
    'R0lGODlhAQABAHD/ACH5BAEKAAAALAAAAAABAAEAAAICRAEAIfkEAQoAAAAsAAAAAAEAAQAAAgJEAQA7',
  );
  test('equivalent gray palette encodings match across runtimes', () async {
    await expectEquivalentOutput(windows, mac, reason: '--gray');
  });
  test('changed timing and disposal are rejected', () async {
    for (final offset in [16, 17]) {
      final changed = Uint8List.fromList(windows);
      changed[offset] ^= 4;
      await expectLater(
        expectEquivalentOutput(changed, windows, reason: 'metadata'),
        throwsA(isA<TestFailure>()),
      );
    }
  });
  test('visible pixels remain exact', () async {
    final black = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAkQBADs=',
    );
    final white = Uint8List.fromList(black);
    white.fillRange(13, 16, 255);
    await expectLater(
      expectEquivalentOutput(white, black, reason: 'pixels'),
      throwsA(isA<TestFailure>()),
    );
  });
  test('text output remains byte exact', () async {
    await expectLater(
      expectEquivalentOutput(
        Uint8List.fromList([65]),
        Uint8List.fromList([66]),
        reason: 'text',
      ),
      throwsA(isA<TestFailure>()),
    );
  });
}
