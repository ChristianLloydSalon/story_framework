import 'dart:async';

import '../../composition/elements/element_styles.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/elements/story_transform.dart';
import '../../core/enums/story_enums.dart';
import '../../core/models/geometry.dart';
import '../../core/models/story_color.dart';
import '../../core/models/story_source.dart';
import '../controller/story_editor_controller.dart';
import '../geometry/element_geometry.dart';
import '../geometry/story_snapping.dart';
import '../widgets/editor_icons.dart';
import 'story_editor_tool.dart';

/// Picks media for the image and video tools, or `null` if cancelled.
///
/// The framework has no picker dependency: apps open their own gallery,
/// camera, or file dialog and return a source.
typedef StoryMediaPicker = Future<StorySource?> Function();

/// Picks a sticker for the sticker tool, or `null` if cancelled.
typedef StoryStickerPicker = Future<StickerContent?> Function();

/// The default tools, in toolbar order.
///
/// Image and video tools are included only when a picker is supplied.
List<StoryEditorTool> defaultStoryEditorTools({
  StoryMediaPicker? imagePicker,
  StoryMediaPicker? videoPicker,
  StoryStickerPicker? stickerPicker,
}) =>
    [
      StorySelectTool(),
      StoryTextTool(),
      if (imagePicker != null) StoryImageTool(imagePicker),
      if (videoPicker != null) StoryVideoTool(videoPicker),
      StoryStickerTool(picker: stickerPicker),
      StoryShapeTool(),
      StoryDrawTool(),
      StoryEraserTool(),
    ];

/// Selects, moves, and drag-selects elements. Double-tap edits text.
///
/// Moving snaps to the canvas edges, center, safe area, and other elements
/// (see `StoryEditorConfig.snapping`), and shows alignment guides.
final class StorySelectTool extends StoryEditorTool {
  /// Tool id.
  static const String toolId = 'select';

  Map<String, StoryTransform> _originals = const {};
  StoryRect? _movingBounds;
  List<StoryRect> _targets = const [];
  StoryPoint? _origin;
  bool _marquee = false;

  @override
  String get id => toolId;

  @override
  String get label => 'Select';

  @override
  String get symbol => '↖';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.select;

  @override
  void onTap(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    final item = controller.currentItem;
    if (item == null) return;
    final hit = StoryElementGeometry.hitTest(item, point,
        tolerance: context.canvasDistance(6));
    if (hit == null) {
      if (!context.additive) controller.clearSelection();
    } else if (context.additive) {
      controller.toggleSelection(hit.id);
    } else {
      controller.select([hit.id]);
    }
  }

  @override
  void onDoubleTap(StoryToolContext context, StoryPoint point) {
    final item = context.controller.currentItem;
    if (item == null) return;
    final hit = StoryElementGeometry.hitTest(item, point,
        tolerance: context.canvasDistance(6));
    if (hit is TextElement) context.controller.beginTextEditing(hit.id);
  }

  @override
  void onDragStart(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    final item = controller.currentItem;
    _origin = point;
    if (item == null) return;
    final hit = StoryElementGeometry.hitTest(item, point,
        tolerance: context.canvasDistance(6));
    if (hit == null) {
      _marquee = true;
      controller.marquee.value = StoryRect.fromPoints(point, point);
      return;
    }
    _marquee = false;
    if (!controller.selection.contains(hit.id)) {
      controller.select([hit.id], additive: context.additive);
    }
    final moving = controller.editableSelection;
    if (moving.isEmpty) return;
    controller.beginTransaction('Move');
    _originals = {for (final e in moving) e.id: e.transform};
    _movingBounds = StoryElementGeometry.unionBounds(_originals.values);
    final canvas = controller.document.canvas;
    _targets = [
      canvas.bounds,
      canvas.safeBounds,
      for (final e in item.elements)
        if (e.visible &&
            !_originals.containsKey(e.id) &&
            !e.transform.size.isEmpty)
          StoryElementGeometry.bounds(e.transform),
    ];
  }

  @override
  void onDragUpdate(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    final origin = _origin;
    if (origin == null) return;
    if (_marquee) {
      controller.marquee.value = StoryRect.fromPoints(origin, point);
      return;
    }
    final bounds = _movingBounds;
    if (_originals.isEmpty || bounds == null) return;
    var delta = point - origin;
    if (controller.config.snapping) {
      final snap = StorySnapping.snapMove(
        moving: bounds,
        delta: delta,
        targets: _targets,
        threshold: context.canvasDistance(controller.config.snapThreshold),
      );
      delta = snap.delta;
      controller.guides.value = snap.guides;
    }
    controller.updateElements([
      for (final MapEntry(:key, value: transform) in _originals.entries)
        if (controller.elementById(key) case final element?)
          element.copyWithCommon(transform: transform.translate(delta)),
    ], label: 'Move');
  }

  @override
  void onDragEnd(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    if (_marquee) {
      final rect = controller.marquee.value;
      if (rect != null) {
        controller.selectInRect(rect, additive: context.additive);
      }
    } else if (_originals.isNotEmpty) {
      controller.commitTransaction();
    }
    _reset(controller);
  }

  @override
  void onDragCancel(StoryToolContext context) {
    if (!_marquee && _originals.isNotEmpty) {
      context.controller.cancelTransaction();
    }
    _reset(context.controller);
  }

  void _reset(StoryEditorController controller) {
    _originals = const {};
    _movingBounds = null;
    _targets = const [];
    _origin = null;
    _marquee = false;
    controller.guides.value = const [];
    controller.marquee.value = null;
  }
}

/// Adds a text box where tapped and starts editing it.
final class StoryTextTool extends StoryEditorTool {
  /// Creates the tool; new text uses [style].
  StoryTextTool({StoryTextStyle? style})
      : style = style ?? StoryTextStyle(fontSize: 72, fontWeight: 700);

  /// Tool id.
  static const String toolId = 'text';

  /// Style of new text.
  final StoryTextStyle style;

  @override
  String get id => toolId;

  @override
  String get label => 'Text';

  @override
  String get symbol => 'T';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.text;

  @override
  void onTap(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    final canvas = controller.document.canvas;
    final element = TextElement(
      id: controller.newId('text'),
      transform: StoryTransform(
        position: point,
        size: StorySize(canvas.width * 0.8, style.fontSize * 2.4),
      ),
      text: 'Text',
      style: style,
    );
    controller
      ..addElement(element, label: 'Add text')
      ..setActiveTool(StorySelectTool.toolId)
      ..beginTextEditing(element.id);
  }
}

/// Adds a sticker where tapped, from [picker] or a default emoji.
final class StoryStickerTool extends StoryEditorTool {
  /// Creates the tool.
  StoryStickerTool({this.picker, this.fallback = const EmojiSticker('⭐')});

  /// Tool id.
  static const String toolId = 'sticker';

  /// Chooses the sticker; `null` uses [fallback] directly.
  final StoryStickerPicker? picker;

  /// Sticker added when there is no [picker].
  final StickerContent fallback;

  @override
  String get id => toolId;

  @override
  String get label => 'Sticker';

  @override
  String get symbol => '☺';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.sticker;

  @override
  void onTap(StoryToolContext context, StoryPoint point) {
    final choose = picker;
    if (choose == null) {
      _add(context.controller, fallback, point);
      return;
    }
    unawaited(choose().then((sticker) {
      if (sticker != null && !context.controller.isDisposed) {
        _add(context.controller, sticker, point);
      }
    }));
  }

  void _add(StoryEditorController controller, StickerContent sticker,
      StoryPoint point) {
    final side = controller.document.canvas.width * 0.3;
    controller
      ..addElement(
        StickerElement(
          id: controller.newId('sticker'),
          transform:
              StoryTransform(position: point, size: StorySize.square(side)),
          sticker: sticker,
        ),
        label: 'Add sticker',
      )
      ..setActiveTool(StorySelectTool.toolId);
  }
}

/// Adds an image from [picker] where tapped.
final class StoryImageTool extends StoryEditorTool {
  /// Creates the tool.
  StoryImageTool(this.picker);

  /// Tool id.
  static const String toolId = 'image';

  /// Chooses the image.
  final StoryMediaPicker picker;

  @override
  String get id => toolId;

  @override
  String get label => 'Image';

  @override
  String get symbol => '▣';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.image;

  @override
  void onTap(StoryToolContext context, StoryPoint point) {
    unawaited(picker().then((source) {
      final controller = context.controller;
      if (source == null || controller.isDisposed) return;
      final side = controller.document.canvas.width * 0.6;
      controller
        ..addElement(
          ImageElement(
            id: controller.newId('image'),
            transform:
                StoryTransform(position: point, size: StorySize.square(side)),
            source: source,
            fit: StoryFit.contain,
          ),
          label: 'Add image',
        )
        ..setActiveTool(StorySelectTool.toolId);
    }));
  }
}

/// Adds a video from [picker], filling the canvas.
final class StoryVideoTool extends StoryEditorTool {
  /// Creates the tool.
  StoryVideoTool(this.picker);

  /// Tool id.
  static const String toolId = 'video';

  /// Chooses the video.
  final StoryMediaPicker picker;

  @override
  String get id => toolId;

  @override
  String get label => 'Video';

  @override
  String get symbol => '▶';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.video;

  @override
  void onTap(StoryToolContext context, StoryPoint point) {
    unawaited(picker().then((source) {
      final controller = context.controller;
      if (source == null || controller.isDisposed) return;
      final canvas = controller.document.canvas;
      controller
        ..addElement(
          VideoElement(
            id: controller.newId('video'),
            transform: StoryTransform.fromRect(canvas.bounds),
            source: source,
          ),
          label: 'Add video',
        )
        ..setActiveTool(StorySelectTool.toolId);
    }));
  }
}

/// Drags out a shape; a tap adds a default-sized one.
final class StoryShapeTool extends StoryEditorTool {
  /// Creates the tool for [shape] with [fillColor].
  StoryShapeTool({
    this.shape = StoryShapeType.rectangle,
    this.fillColor = const StoryColor(0xFFFFFFFF),
  });

  /// Tool id.
  static const String toolId = 'shape';

  /// The shape drawn.
  final StoryShapeType shape;

  /// The fill of new shapes.
  final StoryColor fillColor;

  StoryPoint? _start;
  String? _elementId;

  @override
  String get id => toolId;

  @override
  String get label => 'Shape';

  @override
  String get symbol => '□';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.shape;

  ShapeElement _shape(String id, StoryRect rect) => ShapeElement(
        id: id,
        transform: StoryTransform.fromRect(rect),
        shape: shape,
        fillColor: fillColor,
        cornerRadius: shape == StoryShapeType.rectangle ? 24 : 0,
      );

  @override
  void onTap(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    const side = 300.0;
    controller
      ..addElement(
        _shape(
          controller.newId('shape'),
          StoryRect.fromCenter(point, const StorySize.square(side)),
        ),
        label: 'Add shape',
      )
      ..setActiveTool(StorySelectTool.toolId);
  }

  @override
  void onDragStart(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    _start = point;
    final id = controller.newId('shape');
    _elementId = id;
    controller.beginTransaction('Add shape');
    controller.addElement(
        _shape(id, StoryRect.fromCenter(point, const StorySize.square(1))));
  }

  @override
  void onDragUpdate(StoryToolContext context, StoryPoint point) {
    final start = _start;
    final id = _elementId;
    if (start == null || id == null) return;
    final minSize = context.controller.config.minElementSize;
    var rect = StoryRect.fromPoints(start, point);
    if (rect.width < minSize || rect.height < minSize) {
      rect = StoryRect.fromCenter(
        rect.center,
        StorySize(
          rect.width < minSize ? minSize : rect.width,
          rect.height < minSize ? minSize : rect.height,
        ),
      );
    }
    context.controller.updateElement(_shape(id, rect));
  }

  @override
  void onDragEnd(StoryToolContext context, StoryPoint point) {
    context.controller
      ..commitTransaction()
      ..setActiveTool(StorySelectTool.toolId);
    _start = null;
    _elementId = null;
  }

  @override
  void onDragCancel(StoryToolContext context) {
    context.controller.cancelTransaction();
    _start = null;
    _elementId = null;
  }
}

/// Draws freehand strokes with the controller's brush.
///
/// Strokes go into the selected drawing element, or into a new drawing
/// element covering the canvas. Each stroke is one undo step.
class StoryDrawTool extends StoryEditorTool {
  /// Creates the tool.
  StoryDrawTool();

  /// Tool id.
  static const String toolId = 'draw';

  String? _drawingId;
  final List<StoryPoint> _points = [];

  /// Strokes the drawing had when the current drag started.
  List<StoryDrawingStroke> _base = const [];

  /// The stroke tool used for new strokes.
  StoryDrawingTool get strokeTool => StoryDrawingTool.pen;

  @override
  String get id => toolId;

  @override
  String get label => 'Draw';

  @override
  String get symbol => '✎';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.draw;

  @override
  bool get showsSelection => false;

  /// The drawing to add strokes to, or `null` to create one.
  DrawingElement? targetDrawing(StoryEditorController controller) {
    final selected = controller.editableSelection;
    if (selected.length == 1 && selected.single is DrawingElement) {
      return selected.single as DrawingElement;
    }
    return null;
  }

  @override
  void onTap(StoryToolContext context, StoryPoint point) {
    onDragStart(context, point);
    onDragEnd(context, point);
  }

  @override
  void onDragStart(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    var drawing = targetDrawing(controller);
    if (drawing == null && strokeTool == StoryDrawingTool.eraser) return;
    controller.beginTransaction(
        strokeTool == StoryDrawingTool.eraser ? 'Erase' : 'Draw');
    if (drawing == null) {
      drawing = DrawingElement(
        id: controller.newId('drawing'),
        transform: StoryTransform.fromRect(controller.document.canvas.bounds),
      );
      controller.addElement(drawing);
    }
    _drawingId = drawing.id;
    _base = drawing.strokes;
    _points
      ..clear()
      ..add(StoryElementGeometry.toLocal(drawing.transform, point));
    _apply(controller);
  }

  @override
  void onDragUpdate(StoryToolContext context, StoryPoint point) {
    final controller = context.controller;
    final drawing = _current(controller);
    if (drawing == null) return;
    final local = StoryElementGeometry.toLocal(drawing.transform, point);
    final last = _points.lastOrNull;
    if (last != null &&
        (local.x - last.x).abs() < 1.5 &&
        (local.y - last.y).abs() < 1.5) {
      return;
    }
    _points.add(local);
    _apply(controller);
  }

  @override
  void onDragEnd(StoryToolContext context, StoryPoint point) {
    if (_drawingId != null) context.controller.commitTransaction();
    _finish();
  }

  @override
  void onDragCancel(StoryToolContext context) {
    if (_drawingId != null) context.controller.cancelTransaction();
    _finish();
  }

  void _finish() {
    _drawingId = null;
    _base = const [];
    _points.clear();
  }

  DrawingElement? _current(StoryEditorController controller) {
    final id = _drawingId;
    if (id == null) return null;
    final element = controller.elementById(id);
    return element is DrawingElement ? element : null;
  }

  void _apply(StoryEditorController controller) {
    final drawing = _current(controller);
    if (drawing == null) return;
    final brush = controller.brush.value;
    final stroke = StoryDrawingStroke(
      points: _points,
      color: brush.color,
      width: brush.width,
      opacity: brush.opacity,
      tool: strokeTool,
    );
    controller.updateElement(drawing.copyWith(strokes: [..._base, stroke]));
  }
}

/// Erases parts of the selected drawing with eraser strokes.
final class StoryEraserTool extends StoryDrawTool {
  /// Creates the tool.
  StoryEraserTool();

  /// Tool id.
  static const String eraserToolId = 'eraser';

  @override
  String get id => eraserToolId;

  @override
  String get label => 'Eraser';

  @override
  String get symbol => '⌫';

  @override
  StoryEditorIcons get icon => StoryEditorIcons.eraser;

  @override
  StoryDrawingTool get strokeTool => StoryDrawingTool.eraser;

  @override
  DrawingElement? targetDrawing(StoryEditorController controller) {
    final selected = super.targetDrawing(controller);
    if (selected != null) return selected;
    final item = controller.currentItem;
    if (item == null) return null;
    for (final element in item.elementsInPaintOrder.reversed) {
      if (element is DrawingElement && !element.locked && element.visible) {
        return element;
      }
    }
    return null;
  }
}
