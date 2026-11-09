import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/editor.dart';

import '../../helpers/editor_fixtures.dart';

/// The mapping the canvas uses at the default 800×600 test size.
const mapping = StoryViewportMapping(
  viewportSize: Size(800, 600),
  canvasSize: StorySize(1080, 1920),
);

Offset screenOf(double x, double y) => mapping.toScreen(StoryPoint(x, y));

class _Host extends StatelessWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      );
}

void main() {
  final disposables = <ChangeNotifier>[];
  tearDown(() {
    for (final d in disposables) {
      d.dispose();
    }
    disposables.clear();
  });

  T track<T extends ChangeNotifier>(T value) {
    disposables.add(value);
    return value;
  }

  Future<StoryEditorController> pumpCanvas(
    WidgetTester tester, {
    StoryDocument? document,
    StoryEditorToolRegistry? tools,
  }) async {
    final controller = track(editorFor(document ??
        editorDoc(elements: [
          ShapeElement(
            id: 'box',
            transform: boxAt(300, 400, 300, 300),
            shape: StoryShapeType.rectangle,
            fillColor: StoryColor.white,
          ),
          ShapeElement(
            id: 'other',
            transform: boxAt(800, 1400, 200, 200),
            shape: StoryShapeType.ellipse,
            fillColor: StoryColor.white,
          ),
        ])));
    final toolRegistry =
        tools ?? track(StoryEditorToolRegistry(defaultStoryEditorTools()));
    final renderers = track(StoryRendererRegistry.withDefaults());
    await tester.pumpWidget(_Host(
      child: StoryEditorCanvas(
        controller: controller,
        tools: toolRegistry,
        renderers: renderers,
      ),
    ));
    return controller;
  }

  Future<void> tap(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
  }

  testWidgets('tapping selects, tapping empty space deselects', (tester) async {
    final controller = await pumpCanvas(tester);
    await tap(tester, screenOf(300, 400));
    expect(controller.selection.elementIds, ['box']);
    expect(find.byType(StoryTransformHandle), findsNWidgets(7));
    await tap(tester, screenOf(1000, 100));
    expect(controller.selection.isEmpty, isTrue);
  });

  testWidgets('dragging moves the element as one undo step with snapping',
      (tester) async {
    final controller = await pumpCanvas(tester);
    final gesture = await tester.startGesture(screenOf(300, 400));
    // Move toward the canvas center so the guides engage.
    for (final step in [
      screenOf(400, 400),
      screenOf(500, 400),
      screenOf(537, 400)
    ]) {
      await gesture.moveTo(step);
      await tester.pump();
    }
    expect(controller.guides.value,
        contains(const StoryGuide(StoryGuideAxis.vertical, 540)));
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);

    final moved = controller.elementById('box');
    expect(moved?.transform.position.x, 540, reason: 'snapped to center');
    expect(controller.guides.value, isEmpty);
    expect(controller.undoLabel, 'Move');
    controller.undo();
    expect(controller.elementById('box')?.transform.position.x, 300);
  });

  testWidgets('drags report the moving elements and pointer position',
      (tester) async {
    final controller = await pumpCanvas(tester);
    final drags = <StoryElementDrag?>[];
    controller.elementDrag
        .addListener(() => drags.add(controller.elementDrag.value));
    final gesture = await tester.startGesture(screenOf(300, 400));
    // Past the touch slop, so the drag has started.
    await gesture.moveTo(screenOf(450, 400));
    await tester.pump();
    await gesture.moveTo(screenOf(470, 420));
    await tester.pump();
    final drag = controller.elementDrag.value;
    expect(drag?.elementIds, ['box']);
    expect(drag?.globalPosition, screenOf(470, 420));

    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    expect(controller.elementDrag.value, isNull);
    expect(drags.first?.elementIds, ['box']);
  });

  testWidgets('dropping on a delete target deletes in one undo step',
      (tester) async {
    final controller = await pumpCanvas(tester);
    final gesture = await tester.startGesture(screenOf(300, 400));
    await gesture.moveTo(screenOf(400, 900));
    await tester.pump();
    // The app's trash target is under the pointer.
    controller.dropToDelete.value = true;
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);

    expect(controller.elementById('box'), isNull);
    expect(controller.dropToDelete.value, isFalse, reason: 'reset on drop');
    expect(controller.undoLabel, 'Delete');
    controller.undo();
    final restored = controller.elementById('box');
    expect(restored?.transform.position.x, 300,
        reason: 'restored where it was before the drag');
    expect(restored?.transform.position.y, 400);
    expect(controller.canUndo, isFalse, reason: 'the move left no step');
  });

  testWidgets('drag-selecting empty space selects overlapping elements',
      (tester) async {
    final controller = await pumpCanvas(tester);
    final gesture = await tester.startGesture(screenOf(50, 50));
    await gesture.moveTo(screenOf(500, 300));
    await tester.pump();
    await gesture.moveTo(screenOf(1000, 1500));
    await tester.pump();
    expect(controller.marquee.value, isNotNull);
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    expect(controller.selection.elementIds, ['box', 'other']);
    expect(controller.marquee.value, isNull);
    expect(find.byType(StoryTransformHandle), findsNWidgets(5),
        reason: 'group scale corners and rotate');
  });

  testWidgets('handles scale, resize, and rotate the selection',
      (tester) async {
    final controller = await pumpCanvas(tester);
    controller.select(['box']);
    await tester.pump();

    Offset handle(String label) =>
        tester.getCenter(find.bySemanticsLabel(label).first);

    // Corner: drag the bottom-right corner outward.
    final corner = screenOf(450, 550);
    await tester.dragFrom(corner, screenOf(600, 700) - corner);
    await tester.pump(kDoubleTapTimeout);
    expect(controller.elementById('box')?.transform.scale, greaterThan(1.5));
    expect(controller.undoLabel, 'Scale');
    controller.undo();
    await tester.pump();

    final width = handle('Resize width');
    await tester.dragFrom(width, const Offset(30, 0));
    await tester.pump(kDoubleTapTimeout);
    expect(
        controller.elementById('box')?.transform.size.width, greaterThan(300));
    controller.undo();
    await tester.pump();

    // Rotate a quarter turn: from above the center to its right.
    final rotate = handle('Rotate');
    final center = screenOf(300, 400);
    final radius = (rotate - center).distance;
    await tester.dragFrom(rotate, center + Offset(radius, 0) - rotate);
    await tester.pump(kDoubleTapTimeout);
    expect(controller.elementById('box')?.transform.rotation,
        closeTo(math.pi / 2, 1e-9),
        reason: 'snapped to 90 degrees');
  });

  testWidgets('text tool adds text and edits it inline in one undo step',
      (tester) async {
    final controller = await pumpCanvas(tester);
    controller.setActiveTool(StoryTextTool.toolId);
    await tester.pump();
    await tap(tester, screenOf(540, 1000));
    expect(controller.activeToolId, StorySelectTool.toolId);
    final id = controller.editingTextId;
    expect(id, isNotNull);
    expect(find.byType(StoryInlineTextEditor), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Hello there');
    await tester.pump();
    expect(
        (controller.elementById(id ?? '') as TextElement).text, 'Hello there');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(controller.editingTextId, isNull);
    expect(controller.undoLabel, 'Edit text');
    controller.undo();
    expect((controller.elementById(id ?? '') as TextElement).text, 'Text');
  });

  testWidgets('double-tapping text starts inline editing', (tester) async {
    final controller = await pumpCanvas(tester,
        document: editorDoc(elements: [textAt('title', 540, 960)]));
    await tester.tapAt(screenOf(540, 960));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(screenOf(540, 960));
    await tester.pump(kDoubleTapTimeout);
    expect(controller.editingTextId, 'title');
  });

  testWidgets('drawing creates editable strokes; the eraser adds to them',
      (tester) async {
    final controller = await pumpCanvas(tester);
    controller.setActiveTool(StoryDrawTool.toolId);
    await tester.pump();
    final gesture = await tester.startGesture(screenOf(200, 1000));
    for (var i = 1; i <= 5; i++) {
      await gesture.moveTo(screenOf(200 + i * 60.0, 1000 + i * 20.0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);

    final drawing =
        controller.currentItem?.elements.whereType<DrawingElement>().single;
    expect(drawing?.strokes, hasLength(1));
    expect(drawing?.strokes.single.points.length, greaterThan(3));
    expect(drawing?.strokes.single.points.first.x, closeTo(200, 2),
        reason: 'local coordinates of a full-canvas drawing equal canvas ones');
    expect(controller.undoLabel, 'Draw');

    controller.setActiveTool(StoryEraserTool.eraserToolId);
    await tester.pump();
    await tester.dragFrom(screenOf(250, 1000), const Offset(40, 0));
    await tester.pump(kDoubleTapTimeout);
    final erased =
        controller.currentItem?.elements.whereType<DrawingElement>().single;
    expect(erased?.strokes.last.tool, StoryDrawingTool.eraser);
  });

  testWidgets('shape tool drags out a shape', (tester) async {
    final controller =
        await pumpCanvas(tester, document: editorDoc(elements: const []));
    controller.setActiveTool(StoryShapeTool.toolId);
    await tester.pump();
    final start = screenOf(100, 100);
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(screenOf(300, 200));
    await tester.pump();
    await gesture.moveTo(screenOf(500, 400));
    await tester.pump();
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    final shape = controller.currentItem?.elements.single;
    expect(shape, isA<ShapeElement>());
    expect(shape?.transform.size.width, closeTo(400, 8));
    expect(controller.undoLabel, 'Add shape');
    expect(controller.activeToolId, StorySelectTool.toolId);
  });

  testWidgets('mouse wheel zooms without touching the document',
      (tester) async {
    final controller = await pumpCanvas(tester);
    final before = tester.getSize(find.byType(FittedBox).first);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    tester.binding.handlePointerEvent(pointer.hover(const Offset(400, 300)));
    tester.binding.handlePointerEvent(pointer.scroll(const Offset(0, -20)));
    await tester.pump();
    final after = tester.getSize(find.byType(FittedBox).first);
    expect(after.width, greaterThan(before.width));
    expect(controller.canUndo, isFalse);
  });

  testWidgets('custom tools receive canvas taps', (tester) async {
    final stamp = _StampTool();
    final tools = track(StoryEditorToolRegistry([StorySelectTool(), stamp]));
    final controller = await pumpCanvas(tester, tools: tools);
    controller.setActiveTool('stamp');
    await tester.pump();
    await tap(tester, screenOf(540, 960));
    expect(stamp.taps.single.x, closeTo(540, 1));
    expect(stamp.taps.single.y, closeTo(960, 1));
    expect(() => tools.register(_StampTool()),
        throwsA(isA<ConfigurationException>()));
  });
}

final class _StampTool extends StoryEditorTool {
  final List<StoryPoint> taps = [];

  @override
  String get id => 'stamp';

  @override
  String get label => 'Stamp';

  @override
  String get symbol => '✱';

  @override
  void onTap(StoryToolContext context, StoryPoint point) => taps.add(point);
}
