import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:gifsicle_flutter/gifsicle_flutter.dart';
import 'package:test/test.dart';

final gif = Uint8List.fromList([
  71,
  73,
  70,
  56,
  57,
  97,
  1,
  0,
  1,
  0,
  128,
  0,
  0,
  0,
  0,
  0,
  255,
  255,
  255,
  33,
  249,
  4,
  1,
  10,
  0,
  0,
  0,
  44,
  0,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  0,
  2,
  2,
  68,
  1,
  0,
  59,
]);
void main() {
  tearDownAll(Gifsicle.disposeForTesting);
  test('default is lossless; options reject invalid boundaries', () {
    expect(const GifsicleOptions().toArguments(), [
      '--optimize=3',
      '--gamma=srgb',
    ]);
    for (final o in [
      const GifsicleOptions(optimizationLevel: 4),
      const GifsicleOptions(lossy: -1),
      const GifsicleOptions(colors: 1),
      const GifsicleOptions(scale: GifsicleScale(x: 0, y: 1)),
      const GifsicleOptions(resize: GifsicleResize.width(0)),
      const GifsicleOptions(gamma: GifsicleGamma.value(double.nan)),
    ]) {
      expect(o.toArguments, throwsArgumentError);
    }
  });
  test('native versions, captured help and honest capabilities', () async {
    expect(Gifsicle.gifsicleVersion, '1.96');
    expect(Gifsicle.bridgeVersion, '1');
    final r = await Gifsicle.executeArguments(['--help']);
    expect(r.exitCode, 0);
    expect(utf8.decode(r.stdout), contains('Gifsicle'));
    final c = await Gifsicle.capabilities();
    expect(c.platform, Platform.operatingSystem);
    expect(c.options.length, greaterThan(100));
    expect(c.supportsOption('--transform-colormap'), false);
  });
  test(
    'real resize via worker, binary stdout and concurrent requests',
    () async {
      final results = await Future.wait(
        List.generate(
          12,
          (_) => Gifsicle.transformBytes(
            gif,
            options: const GifsicleOptions(
              resize: GifsicleResize.exact(width: 16, height: 8),
            ),
          ),
        ),
      );
      for (final r in results) {
        expect(r.bytes[6], 16);
        expect(r.bytes[8], 8);
        expect(r.bytes, results.first.bytes);
      }
    },
  );
  test('malformed input and errors do not poison the worker', () async {
    expect(
      await Gifsicle.executeArguments(['--nonsense']).then((r) => r.isSuccess),
      false,
    );
    await expectLater(
      Gifsicle.transformBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<GifsicleException>()),
    );
    expect((await Gifsicle.transformBytes(gif)).outputSize, greaterThan(0));
  });
  test('parser abbreviation cannot bypass external command block', () async {
    for (final args in [
      ['--transform-c=echo bad'],
      ['--threads=2'],
    ]) {
      await expectLater(
        Gifsicle.executeArguments(args),
        throwsA(isA<GifsicleUnsupportedFeatureException>()),
      );
    }
  });
  test('Unicode files, no-clobber and same-path replacement', () async {
    final dir = await Directory.systemTemp.createTemp('gs-test-');
    try {
      final f = File('${dir.path}/中文 空格 😀.gif');
      await f.writeAsBytes(gif);
      await expectLater(
        Gifsicle.transformFile(inputPath: f.path, outputPath: f.path),
        throwsA(isA<GifsicleException>()),
      );
      expect(await f.readAsBytes(), gif);
      final r = await Gifsicle.transformFile(
        inputPath: f.path,
        outputPath: f.path,
        overwrite: true,
      );
      expect(r.outputSize, greaterThan(0));
      expect((await f.readAsBytes()).take(3), [71, 73, 70]);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('staged explicit outputs, explode, batch and path isolation', () async {
    final command = await Gifsicle.execute(
      GifsicleCommand(
        arguments: [
          GifsicleArgument.inputBytes(id: 'in', bytes: gif),
          const GifsicleArgument.option('--output'),
          const GifsicleArgument.outputMemory(id: 'out'),
        ],
      ),
    );
    expect(
      (command.outputs['out'] as GifsicleMemoryOutputArtifact).bytes.take(3),
      [71, 73, 70],
    );
    expect(command.generatedFiles, isEmpty);
    for (final mode in ['--explode', '--batch']) {
      final r = await Gifsicle.execute(
        GifsicleCommand(
          arguments: [
            GifsicleArgument.option(mode),
            const GifsicleArgument.option('--resize=2x2'),
            GifsicleArgument.inputBytes(id: 'in', bytes: gif),
          ],
        ),
      );
      expect(r.isSuccess, true);
      expect(r.generatedFiles, isNotEmpty);
    }
    for (final path in ['../escape.gif', '/tmp/escape.gif', 'a/b.gif']) {
      await expectLater(
        Gifsicle.execute(
          GifsicleCommand(
            arguments: [
              GifsicleArgument.inputBytes(id: 'in', bytes: gif),
              GifsicleArgument.option('--output=$path'),
            ],
          ),
        ),
        throwsA(isA<GifsicleException>()),
      );
    }
  });
  test('limits, NUL, duplicate IDs and selector validation', () async {
    await expectLater(
      Gifsicle.executeArguments(['--help\u0000']),
      throwsArgumentError,
    );
    await expectLater(
      Gifsicle.execute(
        GifsicleCommand(
          arguments: [GifsicleArgument.inputBytes(id: 'a', bytes: gif)],
          limits: const GifsicleLimits(maxInputBytes: 2),
        ),
      ),
      throwsA(isA<GifsicleException>()),
    );
    await expectLater(
      Gifsicle.execute(
        GifsicleCommand(
          arguments: [
            GifsicleArgument.inputBytes(id: 'a', bytes: gif),
            GifsicleArgument.inputBytes(id: 'a', bytes: gif),
          ],
        ),
      ),
      throwsArgumentError,
    );
  });
  test('multiple initiating isolates share native mutex', () async {
    final bytes = await Isolate.run(() async {
      try {
        return (await Gifsicle.transformBytes(gif)).bytes;
      } finally {
        await Gifsicle.disposeForTesting();
      }
    });
    expect(bytes.take(3), [71, 73, 70]);
  });

  test('dither validation and original parser overflow regression', () async {
    expect(
      const GifsicleOptions(dither: GifsicleDither('unknown')).toArguments,
      throwsArgumentError,
    );
    expect(
      const GifsicleOptions(
        dither: GifsicleDither('ordered,1,2,3,4,5'),
      ).toArguments,
      throwsArgumentError,
    );
    final r = await Gifsicle.executeArguments([
      '--dither=ordered,1,2,3,4,5,6',
      '-',
    ], stdin: gif);
    expect(r.isSuccess, false);
  });
  test(
    'truncated descriptors and oversized frame limits fail safely',
    () async {
      final bad = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///y8AAAL//wEKAAAALAAAAAAB/wA7',
      );
      await expectLater(
        Gifsicle.transformBytes(bad),
        throwsA(isA<GifsicleException>()),
      );
      final large = Uint8List.fromList(gif);
      large[6] = 100;
      large[8] = 100;
      await expectLater(
        Gifsicle.execute(
          GifsicleCommand(
            arguments: [const GifsicleArgument.literal('-')],
            stdin: large,
            limits: const GifsicleLimits(maxCanvasPixels: 100),
          ),
        ),
        throwsA(isA<GifsicleException>()),
      );
    },
  );
  test(
    'dispose drains existing work; new requests restart after disposal',
    () async {
      final pending = Gifsicle.transformBytes(gif);
      final disposed = Gifsicle.disposeForTesting();
      final next = Gifsicle.executeArguments(['--version']);
      await pending;
      await disposed;
      expect((await next).isSuccess, true);
    },
  );
  test('worker restarts after drained disposal', () async {
    await Gifsicle.disposeForTesting();
    expect((await Gifsicle.executeArguments(['--version'])).isSuccess, true);
  });
}
