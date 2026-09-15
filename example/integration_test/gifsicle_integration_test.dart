import 'dart:io';
import 'dart:convert';

import 'cli_cases.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gifsicle_flutter/gifsicle_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('packaged native assets transform GIF and keep UI responsive', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Text('ready')));
    final bytes = Uint8List.fromList([
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
    final future = Gifsicle.transformBytes(
      bytes,
      options: const GifsicleOptions(
        resize: GifsicleResize.exact(width: 32, height: 16),
      ),
    );
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
    final r = await future;
    expect(r.bytes[6], 32);
    expect(r.bytes[8], 16);
    await tester.pumpWidget(MaterialApp(home: Image.memory(r.bytes)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect((await Gifsicle.capabilities()).platform, Platform.operatingSystem);
    expect((await Gifsicle.executeArguments(['--help'])).stdout, isNotEmpty);
    await expectLater(
      Gifsicle.executeArguments(['--transform-c=blocked']),
      throwsA(isA<GifsicleUnsupportedFeatureException>()),
    );
    final dir = await Directory.systemTemp.createTemp('gs-integration-');
    try {
      final file = File('${dir.path}/中文 😀.gif');
      await file.writeAsBytes(bytes);
      await Gifsicle.transformFile(
        inputPath: file.path,
        outputPath: file.path,
        overwrite: true,
      );
      expect((await file.readAsBytes()).take(3), [71, 73, 70]);
    } finally {
      await dir.delete(recursive: true);
      await Gifsicle.disposeForTesting();
    }
  });
  testWidgets('all 112 CLI parser entries match reference fixtures', (
    tester,
  ) async {
    final cases = jsonDecode(cliCasesJson) as List;
    final original = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///yH5BAEKAAAALAAAAAABAAEAAAICRAEAIfkEAQoAAAAsAAAAAAEAAQAAAgJEAQA7',
    );
    final dir = await Directory.systemTemp.createTemp('gs-conformance-');
    try {
      for (final c in cases) {
        await for (final f in dir.list()) {
          await f.delete();
        }
        await File('${dir.path}/input.gif').writeAsBytes(original);
        final args = (c['arguments'] as List).cast<String>();
        if (c['bridgeStatus'] == 10) {
          await expectLater(
            Gifsicle.executeArguments(args, workingDirectory: dir.path),
            throwsA(isA<GifsicleUnsupportedFeatureException>()),
          );
          continue;
        }
        late GifsicleExecutionResult r;
        try {
          r = await Gifsicle.executeArguments(args, workingDirectory: dir.path);
        } catch (e) {
          fail('${c['name']}: $e');
        }
        expect(r.exitCode, c['exitCode'], reason: c['name']);
        expect(base64Encode(r.stdout), c['expectedStdout'], reason: c['name']);
        final actual = <String, String>{};
        await for (final f in dir.list()) {
          actual[f.uri.pathSegments.last] = base64Encode(
            await File(f.path).readAsBytes(),
          );
        }
        expect(actual, c['expectedFiles'], reason: c['name']);
      }
    } finally {
      await dir.delete(recursive: true);
      await Gifsicle.disposeForTesting();
    }
  });
}
