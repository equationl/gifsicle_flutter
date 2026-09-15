import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gifsicle_flutter/gifsicle_flutter.dart';
import 'package:gifsicle_flutter_example/demo_catalog.dart';
import 'package:gifsicle_flutter_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('every demo runs against packaged native library', (
    tester,
  ) async {
    final data = await rootBundle.load('assets/sample.gif');
    final sample = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    for (final demo in demos) {
      try {
        final r = await runDemo(demo, sample);
        expect(r.text, isNotEmpty, reason: demo.id);
        if (demo.id != 'errors') {
          expect(r.text, isNot(contains('isSuccess=false')), reason: demo.id);
        }
        for (final image in r.images.values) {
          expect(isGif(image), isTrue, reason: demo.id);
        }
      } catch (e) {
        fail('${demo.id}: $e');
      }
    }
    await Gifsicle.disposeForTesting();
  });
  testWidgets('mobile and desktop layout and run button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: ExampleApp()));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('run-demo')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('输出/输入比'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await Gifsicle.disposeForTesting();
  });
}
