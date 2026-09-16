import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gifsicle_flutter/gifsicle_flutter.dart';
import 'package:gifsicle_flutter_example/demo_catalog.dart';
import 'package:gifsicle_flutter_example/main.dart';

Future<void> waitFor(
  WidgetTester tester,
  bool Function() ready,
  String label,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $label');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.reportData = {'completedTests': 0};
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
    binding.reportData!['completedTests'] =
        (binding.reportData!['completedTests'] as int) + 1;
  });
  testWidgets('mobile and desktop layout and run button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Reproduce a constrained render surface whose physical-window MediaQuery
    // stays wide (as observed with the Windows integration binding).
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1600, 1000)),
          child: ExampleApp(),
        ),
      ),
    );
    await waitFor(tester, () {
      final button = find.byKey(const Key('run-demo'));
      return button.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(button).onPressed != null;
    }, 'demo initialization');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('run-demo')));
    await tester.tap(find.byKey(const Key('run-demo')));
    await waitFor(
      tester,
      () => find.textContaining('输出/输入比').evaluate().isNotEmpty,
      'GIF conversion result',
    );
    expect(find.textContaining('输出/输入比'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await Gifsicle.disposeForTesting();
    binding.reportData!['completedTests'] =
        (binding.reportData!['completedTests'] as int) + 1;
  });
}
