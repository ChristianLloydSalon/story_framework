import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/story_framework.dart';
import 'package:story_framework_example/examples/11_mobile_editor/main.dart';

void main() {
  Future<StoryEditorController> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MobileEditorPage()));
    await tester.pumpAndSettle();
    final layout =
        tester.widget<MobileEditorLayout>(find.byType(MobileEditorLayout));
    return layout.parts.controller;
  }

  int elementCount(StoryEditorController controller) =>
      controller.currentItem?.elements.length ?? 0;

  testWidgets('adds emojis from the sheet', (tester) async {
    final controller = await pumpEditor(tester);
    expect(elementCount(controller), 1);
    await tester.tap(find.bySemanticsLabel('Add emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add 🔥'));
    await tester.pumpAndSettle();
    expect(elementCount(controller), 2);
    final added = controller.selectedElements.single;
    expect(added, isA<StickerElement>());
  });

  testWidgets('text left empty is removed when typing ends', (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.bySemanticsLabel('Add text'));
    await tester.pumpAndSettle();
    expect(controller.editingTextId, isNotNull);
    expect(elementCount(controller), 2);
    controller.endTextEditing();
    await tester.pumpAndSettle();
    expect(elementCount(controller), 1);
  });

  testWidgets('dragging onto the trash deletes; undo restores', (tester) async {
    final controller = await pumpEditor(tester);
    final canvas = tester.getRect(find.byType(StoryEditorCanvas));
    // The wave sticker sits in the middle of the story.
    final gesture = await tester.startGesture(canvas.center);
    await gesture.moveTo(canvas.center + const Offset(0, 60));
    await tester.pump();
    expect(find.byType(TrashTarget), findsOneWidget);
    expect(find.bySemanticsLabel('Add text'), findsOneWidget,
        reason: 'hidden controls stay in the tree, just faded');

    final trash = tester.getCenter(find.byType(TrashTarget));
    await gesture.moveTo(trash);
    await tester.pump();
    expect(controller.dropToDelete.value, isTrue);
    expect(find.bySemanticsLabel('Release to delete'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(elementCount(controller), 0);
    expect(find.byType(TrashTarget), findsNothing);

    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pumpAndSettle();
    expect(elementCount(controller), 1);
    expect(controller.currentItem?.elements.single.transform.position,
        const StoryPoint(540, 960),
        reason: 'back where it was before the drag');
  });

  testWidgets('dropping away from the trash just moves', (tester) async {
    final controller = await pumpEditor(tester);
    final canvas = tester.getRect(find.byType(StoryEditorCanvas));
    final gesture = await tester.startGesture(canvas.center);
    await gesture.moveTo(canvas.center + const Offset(0, -80));
    await tester.pump();
    await gesture.moveTo(canvas.center + const Offset(40, -120));
    await tester.pump();
    expect(controller.dropToDelete.value, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(elementCount(controller), 1);
    expect(controller.undoLabel, 'Move');
  });

  testWidgets('drawing mode shows its own controls', (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.bySemanticsLabel('Draw'));
    await tester.pumpAndSettle();
    expect(controller.activeToolId, StoryDrawTool.toolId);
    expect(find.byType(StorySwatchRow), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(controller.activeToolId, StorySelectTool.toolId);
  });
}
