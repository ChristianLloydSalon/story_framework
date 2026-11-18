import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/story_framework.dart';
import 'package:story_framework_playground/main.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PlaygroundApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the editor and preview side by side when wide',
      (tester) async {
    await pumpAt(tester, const Size(1400, 900));

    expect(find.byType(StoryEditor), findsOneWidget);
    expect(find.byType(StoryViewer), findsOneWidget);
    // No pane toggle.
    expect(find.text('Edit'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('switches between editing and previewing when narrow',
      (tester) async {
    await pumpAt(tester, const Size(420, 860));

    expect(find.byType(StoryEditor), findsOneWidget);
    expect(find.byType(StoryViewer), findsNothing);

    await tester.tap(find.text('Preview'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(StoryEditor), findsNothing);
    expect(find.byType(StoryViewer), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(StoryEditor), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
