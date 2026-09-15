import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isGif(Uint8List bytes) =>
    bytes.length >= 6 &&
    (String.fromCharCodes(bytes.take(6)) == 'GIF87a' ||
        String.fromCharCodes(bytes.take(6)) == 'GIF89a');

/// Keep byte equality for text and identical GIFs. Palette ordering and LZW
/// encodings may differ across C runtimes, so compare GIF content independently.
Future<void> expectEquivalentOutput(
  Uint8List actual,
  Uint8List expected, {
  required String reason,
}) async {
  if (listEquals(actual, expected)) return;
  if (!_isGif(actual) || !_isGif(expected)) {
    expect(actual, orderedEquals(expected), reason: reason);
    return;
  }
  expect(
    _metadata(actual),
    _metadata(expected),
    reason: '$reason: GIF metadata',
  );
  final expectedCodec = await ui.instantiateImageCodec(expected);
  try {
    final actualCodec = await ui.instantiateImageCodec(actual);
    try {
      expect(
        actualCodec.frameCount,
        expectedCodec.frameCount,
        reason: '$reason: frame count',
      );
      expect(
        actualCodec.repetitionCount,
        expectedCodec.repetitionCount,
        reason: '$reason: loop count',
      );
      for (var i = 0; i < expectedCodec.frameCount; i++) {
        final expectedFrame = await expectedCodec.getNextFrame();
        try {
          final actualFrame = await actualCodec.getNextFrame();
          try {
            expect(
              actualFrame.duration,
              expectedFrame.duration,
              reason: '$reason: frame $i duration',
            );
            expect(
              actualFrame.image.width,
              expectedFrame.image.width,
              reason: '$reason: frame $i width',
            );
            expect(
              actualFrame.image.height,
              expectedFrame.image.height,
              reason: '$reason: frame $i height',
            );
            expect(
              await _pixels(actualFrame.image),
              orderedEquals(await _pixels(expectedFrame.image)),
              reason: '$reason: frame $i RGBA',
            );
          } finally {
            actualFrame.image.dispose();
          }
        } finally {
          expectedFrame.image.dispose();
        }
      }
    } finally {
      actualCodec.dispose();
    }
  } finally {
    expectedCodec.dispose();
  }
}

Future<Uint8List> _pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('GIF frame could not be decoded');
  final bytes = Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  // RGB values under alpha=0 have no visible meaning.
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i + 3] == 0) bytes.fillRange(i, i + 3, 0);
  }
  return bytes;
}

/// Preserve frame geometry, interlace, exact delay/disposal/flags, comments,
/// names and application extensions (including loop settings). Only palette
/// data, transparent palette indices and compressed pixels are normalized.
List<Object> _metadata(Uint8List bytes) {
  var pos = 0;
  List<int> take(int length) {
    if (pos + length > bytes.length) {
      throw const FormatException('Truncated GIF');
    }
    final result = bytes.sublist(pos, pos + length);
    pos += length;
    return result;
  }

  List<int> blocks() {
    final result = <int>[];
    while (true) {
      final length = take(1).single;
      if (length == 0) return result;
      result.addAll(take(length));
    }
  }

  take(6);
  final screen = take(7);
  final result = <Object>['screen', screen.sublist(0, 4), screen[6]];
  if (screen[4] & 128 != 0) take(3 * (1 << ((screen[4] & 7) + 1)));
  while (true) {
    final marker = take(1).single;
    if (marker == 0x3b) {
      // Do not silently ignore a second stream or trailing content.
      result.add(take(bytes.length - pos));
      return result;
    }
    if (marker == 0x21) {
      final label = take(1).single;
      final payload = blocks();
      if (label == 0xf9) {
        if (payload.length != 4) {
          throw const FormatException('Invalid GIF control extension');
        }
        payload[3] = 0;
      }
      result.addAll(['extension', label, payload]);
    } else if (marker == 0x2c) {
      final frame = take(9);
      result.addAll(['frame', frame.sublist(0, 8), frame[8] & 0x40]);
      if (frame[8] & 128 != 0) take(3 * (1 << ((frame[8] & 7) + 1)));
      take(1); // LZW minimum code size; decoded pixels are checked above.
      blocks();
    } else {
      throw FormatException('Unexpected GIF block $marker');
    }
  }
}
