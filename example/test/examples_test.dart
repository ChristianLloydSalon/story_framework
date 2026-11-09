import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/story_framework.dart';
import 'package:story_framework_example/examples/gallery.dart';
import 'package:story_framework_example/examples/shared.dart';

void main() {
  // Examples 2 and 5 need the network, so they are not opened here.
  final offline = allExamples.where((e) => e.number != 2 && e.number != 5);

  for (final example in offline) {
    testWidgets('example ${example.number} opens: ${example.title}',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ExampleApp(example: example));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.byType(ExampleLauncherPage), findsNothing,
          reason: 'the example page covers the launcher');
      // Unmount so viewers and controllers dispose cleanly.
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('example 7 round-trips losslessly', (tester) async {
    await tester.pumpWidget(MaterialApp(home: allExamples[6].page));
    expect(find.text('Round trip is lossless'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Valid'), findsNothing);
  });

  testWidgets('example 8 exports PNGs', (tester) async {
    await tester.pumpWidget(MaterialApp(home: allExamples[7].page));
    await tester.runAsync(() async {
      await tester.tap(find.text('Export PNGs'));
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.textContaining('Exported').evaluate().isNotEmpty) break;
      }
    });
    expect(find.text('Exported 6 file(s)'), findsOneWidget);
    expect(find.byType(StoryViewer), findsNothing);
  });
}
