import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/editor.dart';

import '../../fixtures/sample_document.dart';
import '../../helpers/editor_fixtures.dart';

class _Host extends StatelessWidget {
  const _Host({required this.child, this.size = const Size(1200, 800)});

  final Widget child;
  final Size size;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      );
}

void main() {
  Future<StoryEditorController> pumpEditor(
    WidgetTester tester, {
    StoryDocument? document,
    ValueChanged<StoryDocument>? onChanged,
    Size size = const Size(1200, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = editorFor(document ?? editorDoc());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_Host(
      size: size,
      child: StoryEditor(controller: controller, onChanged: onChanged),
    ));
    await tester.pump();
    return controller;
  }

  testWidgets('shows the toolbar, layers, and timeline', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(StoryEditorToolbar), findsOneWidget);
    expect(find.byType(StoryLayersPanel), findsOneWidget);
    expect(find.byType(StoryTimelinePanel), findsOneWidget);
    expect(find.text('“t1”'), findsOneWidget);
  });

  testWidgets('narrow layouts drop the side panel', (tester) async {
    await pumpEditor(tester, size: const Size(500, 900));
    expect(find.byType(StoryLayersPanel), findsNothing);
    expect(find.byType(StoryPropertiesPanel), findsOneWidget);
  });

  testWidgets('layer rows select without gestures on the canvas',
      (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.bySemanticsLabel('Select layer “t2”'));
    await tester.pump();
    expect(controller.selection.elementIds, ['t2']);
    await tester.tap(find.bySemanticsLabel('Lock “t2”'));
    await tester.pump();
    expect(controller.elementById('t2')?.locked, isTrue);
  });

  testWidgets('keyboard shortcuts delete, undo, redo, nudge, select all',
      (tester) async {
    final changes = <StoryDocument>[];
    final controller = await pumpEditor(tester, onChanged: changes.add);
    controller.select(['t1']);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(controller.elementById('t1')?.transform.position.x, 201);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(controller.elementById('t1')?.transform.position.y, 210);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(controller.elementById('t1'), isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    expect(controller.elementById('t1'), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    expect(controller.elementById('t1'), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    expect(controller.selection.elementIds, ['t2', 't3']);
    expect(changes, hasLength(5));
  });

  testWidgets('toolbar undo and redo reflect history', (tester) async {
    final controller = await pumpEditor(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Undo')),
      isSemantics(
        label: 'Undo',
        isButton: true,
        isEnabled: false,
        hasSelectedState: false,
      ),
      reason: 'disabled until there is something to undo, and not a toggle',
    );
    controller.select(['t1']);
    controller.deleteSelection();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Undo Delete'));
    await tester.pump();
    expect(controller.elementById('t1'), isNotNull);
  });

  testWidgets('timeline adds stories, changes duration and transition',
      (tester) async {
    final controller = await pumpEditor(tester);
    await tester.tap(find.bySemanticsLabel('Add story'));
    await tester.pump();
    expect(controller.currentGroupItems, hasLength(3));
    final added = controller.currentItemId ?? '';

    await tester.tap(find.bySemanticsLabel('Longer'));
    await tester.pump();
    expect(controller.document.itemById(added)?.duration,
        const FixedItemDuration(Duration(seconds: 6)));

    await tester.tap(find.bySemanticsLabel('Transition default, change'));
    await tester.pump();
    expect(controller.document.itemById(added)?.transition?.type, 'none');

    await tester.tap(find.bySemanticsLabel('Story 1'));
    await tester.pump();
    expect(controller.currentItemId, 'a');
    await tester.tap(find.bySemanticsLabel('Move story later'));
    await tester.pump();
    expect(controller.currentGroupItems[1].id, 'a');
  });

  testWidgets('properties panel transforms without gestures', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(['t1']);
    await tester.pump();
    for (final label in [
      'Make larger',
      'Rotate right 15 degrees',
      'Larger text',
    ]) {
      final button = find.bySemanticsLabel(label);
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
    }
    final text = controller.elementById('t1') as TextElement;
    expect(text.transform.scale, closeTo(1.1, 1e-9));
    expect(text.transform.rotation, greaterThan(0));
    expect(text.style.fontSize, 56);
  });

  testWidgets('interactive elements are inert previews in the editor',
      (tester) async {
    await pumpEditor(tester,
        document: editorDoc(
            elements: sampleInteractiveElements()
                .where((e) => e.interaction is! StoryCustomInteraction)
                .toList()));
    expect(find.text('Tea or coffee?'), findsWidgets);
    expect(find.byType(EditableText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owns a controller and reports changes when given a document',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changes = <StoryDocument>[];
    await tester.pumpWidget(_Host(
      child: StoryEditor(document: editorDoc(), onChanged: changes.add),
    ));
    await tester.tap(find.bySemanticsLabel('Add story'));
    await tester.pump();
    expect(changes.single.allItems, hasLength(4));
    await tester.pumpWidget(const SizedBox());
  });
}
