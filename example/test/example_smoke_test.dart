import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/story_framework.dart';
import 'package:story_framework_example/main.dart';

void main() {
  testWidgets('opens a story from the tray and closes it', (tester) async {
    await tester.pumpWidget(const StoryExampleApp());
    expect(find.text('Stories'), findsOneWidget);

    await tester.tap(find.text('Grace'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryViewer), findsOneWidget);
    expect(find.text('Swipe left\nfor the next person'), findsOneWidget);

    await tester.tapAt(const Offset(700, 300));
    await tester.pump();
    expect(find.text('Hold to pause'), findsOneWidget);

    await tester.dragFrom(const Offset(400, 200), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(StoryViewer), findsNothing);
  });

  testWidgets('opens the editor and previews the draft', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const StoryExampleApp());
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryEditor), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Add story'));
    await tester.pump();
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryViewer), findsOneWidget);
  });
}
