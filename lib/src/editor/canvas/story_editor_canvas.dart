import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../composition/elements/story_element.dart';
import '../../composition/elements/story_transform.dart';
import '../../core/models/geometry.dart';
import '../../rendering/contracts/story_element_renderer.dart';
import '../../rendering/conversions.dart';
import '../../rendering/options/story_render_options.dart';
import '../../rendering/registry/story_renderer_registry.dart';
import '../../rendering/widgets/story_item_view.dart';
import '../controller/story_editor_controller.dart';
import '../geometry/element_geometry.dart';
import '../geometry/story_snapping.dart';
import '../geometry/transform_math.dart';
import '../tools/builtin_tools.dart';
import '../tools/story_editor_tool.dart';
import 'story_editor_viewport.dart';

const Color _accent = Color(0xFF4C8DFF);

/// The editing surface: shows the current item, forwards gestures to the
/// active tool, and draws selection handles, alignment guides, and the
/// drag-selection rectangle.
///
/// Gestures:
///
/// | Input | Effect |
/// |---|---|
/// | One finger / mouse | Sent to the active tool (select, draw, ...) |
/// | Two-finger pinch or drag | Zoom and pan the viewport |
/// | Mouse wheel | Zoom around the pointer |
/// | Handles | Scale (corners), resize (edges), rotate (top) |
///
/// The viewport (zoom and pan) is view state: it never changes the
/// document or creates undo steps.
class StoryEditorCanvas extends StatefulWidget {
  /// Creates a canvas for [controller] using the tools in [tools].
  const StoryEditorCanvas({
    required this.controller,
    required this.tools,
    required this.renderers,
    this.renderOptions = const StoryRenderOptions(),
    this.backgroundColor = const Color(0xFF101014),
    super.key,
  });

  /// The editor.
  final StoryEditorController controller;

  /// Available tools; the controller's active tool id picks one.
  final StoryEditorToolRegistry tools;

  /// Element renderers.
  final StoryRendererRegistry renderers;

  /// Rendering options for the canvas content.
  final StoryRenderOptions renderOptions;

  /// Color around the canvas.
  final Color backgroundColor;

  @override
  State<StoryEditorCanvas> createState() => _StoryEditorCanvasState();
}

class _StoryEditorCanvasState extends State<StoryEditorCanvas> {
  final ValueNotifier<StoryEditorViewport> _viewport =
      ValueNotifier(StoryEditorViewport.fit);

  @override
  void dispose() {
    _viewport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([widget.controller, widget.tools, _viewport]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth.isFinite ? constraints.maxWidth : 400,
            constraints.maxHeight.isFinite ? constraints.maxHeight : 700,
          );
          final controller = widget.controller;
          final mapping = StoryViewportMapping(
            viewportSize: size,
            canvasSize: controller.document.canvas.size,
            viewport: _viewport.value,
          );
          final tool = widget.tools.lookup(controller.activeToolId) ??
              widget.tools.lookup(StorySelectTool.toolId);
          final item = controller.currentItem;
          final editingId = controller.editingTextId;
          final editing =
              editingId == null ? null : controller.elementById(editingId);

          return ClipRect(
            child: SizedBox.fromSize(
              size: size,
              child: Stack(
                children: [
                  Positioned.fill(
                      child: ColoredBox(color: widget.backgroundColor)),
                  Positioned.fromRect(
                    rect: mapping.canvasRect,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 32,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: mapping.canvasRect,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: controller.document.canvas.width,
                        height: controller.document.canvas.height,
                        child: item == null
                            ? const ColoredBox(color: Color(0xFF000000))
                            : StoryItemView(
                                document: controller.document,
                                item: item,
                                registry: widget.renderers,
                                options: widget.renderOptions,
                                mode: StoryRenderMode.editor,
                                elementFilter: editingId == null
                                    ? null
                                    : (element) => element.id != editingId,
                              ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: _CanvasInput(
                      controller: controller,
                      tool: tool,
                      mapping: mapping,
                      viewport: _viewport,
                    ),
                  ),
                  if (tool?.showsSelection ?? true)
                    Positioned.fill(
                      child: StorySelectionLayer(
                        controller: controller,
                        mapping: mapping,
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _GuideAndMarqueeLayer(
                        controller: controller,
                        mapping: mapping,
                      ),
                    ),
                  ),
                  if (editing is TextElement)
                    StoryInlineTextEditor(
                      key: ValueKey(('inline-text', editing.id)),
                      controller: controller,
                      element: editing,
                      mapping: mapping,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Converts raw gestures into tool calls and viewport changes.
class _CanvasInput extends StatefulWidget {
  const _CanvasInput({
    required this.controller,
    required this.tool,
    required this.mapping,
    required this.viewport,
  });

  final StoryEditorController controller;
  final StoryEditorTool? tool;
  final StoryViewportMapping mapping;
  final ValueNotifier<StoryEditorViewport> viewport;

  @override
  State<_CanvasInput> createState() => _CanvasInputState();
}

enum _Gesture { none, tool, pinch }

class _CanvasInputState extends State<_CanvasInput> {
  _Gesture _gesture = _Gesture.none;
  StoryEditorTool? _dragTool;
  StoryPoint _lastPoint = StoryPoint.zero;
  StoryViewportMapping? _pinchStart;
  Offset _pinchFocal = Offset.zero;
  Offset _doubleTapAt = Offset.zero;

  /// Where the latest pointer went down. Drag recognition only fires after
  /// the pointer moves past the touch slop, so drags start from here to
  /// avoid losing that distance.
  Offset _downAt = Offset.zero;
  Offset _downAtGlobal = Offset.zero;
  Offset? _pointerGlobal;

  StoryToolContext get _context => StoryToolContext(
        controller: widget.controller,
        mapping: widget.mapping,
        additive: HardwareKeyboard.instance.isShiftPressed,
        globalPosition: _pointerGlobal,
      );

  @override
  void dispose() {
    _cancelToolDrag();
    super.dispose();
  }

  void _cancelToolDrag() {
    final tool = _dragTool;
    if (_gesture == _Gesture.tool &&
        tool != null &&
        !widget.controller.isDisposed) {
      tool.onDragCancel(_context);
    }
    _dragTool = null;
    _gesture = _Gesture.none;
  }

  void _scaleStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      _startPinch(details.localFocalPoint);
      return;
    }
    final tool = widget.tool;
    if (tool == null) return;
    _gesture = _Gesture.tool;
    _dragTool = tool;
    _pointerGlobal = _downAtGlobal;
    tool.onDragStart(_context, widget.mapping.toCanvas(_downAt));
    _pointerGlobal = details.focalPoint;
    _lastPoint = widget.mapping.toCanvas(details.localFocalPoint);
    tool.onDragUpdate(_context, _lastPoint);
  }

  void _startPinch(Offset focal) {
    _cancelToolDrag();
    _gesture = _Gesture.pinch;
    _pinchStart = widget.mapping;
    _pinchFocal = focal;
  }

  void _scaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2 && _gesture != _Gesture.pinch) {
      _startPinch(details.localFocalPoint);
    }
    switch (_gesture) {
      case _Gesture.tool:
        _pointerGlobal = details.focalPoint;
        _lastPoint = widget.mapping.toCanvas(details.localFocalPoint);
        _dragTool?.onDragUpdate(_context, _lastPoint);
      case _Gesture.pinch:
        final start = _pinchStart;
        if (start == null) return;
        final zoomed = start.zoomAround(_pinchFocal, details.scale);
        widget.viewport.value = zoomed.copyWith(
            pan: zoomed.pan + (details.localFocalPoint - _pinchFocal));
      case _Gesture.none:
        break;
    }
  }

  void _scaleEnd(ScaleEndDetails details) {
    if (_gesture == _Gesture.tool) {
      _dragTool?.onDragEnd(_context, _lastPoint);
    }
    _dragTool = null;
    _gesture = _Gesture.none;
    _pinchStart = null;
  }

  void _pointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final factor = event.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1;
    widget.viewport.value =
        widget.mapping.zoomAround(event.localPosition, factor);
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Listener(
      onPointerSignal: _pointerSignal,
      onPointerDown: (event) {
        _downAt = event.localPosition;
        _downAtGlobal = event.position;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: tool == null
            ? null
            : (details) => tool.onTap(
                _context, widget.mapping.toCanvas(details.localPosition)),
        onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
        onDoubleTap: tool == null
            ? null
            : () => tool.onDoubleTap(
                _context, widget.mapping.toCanvas(_doubleTapAt)),
        onScaleStart: _scaleStart,
        onScaleUpdate: _scaleUpdate,
        onScaleEnd: _scaleEnd,
      ),
    );
  }
}

/// What a selection handle does when dragged.
enum StoryHandleKind {
  /// Scale uniformly around the center.
  scale,

  /// Change the width.
  width,

  /// Change the height.
  height,

  /// Rotate around the center.
  rotate,
}

/// Outlines the selection and shows transform handles.
///
/// A single editable element gets corner scale handles, edge resize handles,
/// and a rotate handle. Several elements get scale and rotate handles for the
/// whole group. Locked elements are outlined without handles.
class StorySelectionLayer extends StatefulWidget {
  /// Creates the selection layer.
  const StorySelectionLayer({
    required this.controller,
    required this.mapping,
    super.key,
  });

  /// The editor.
  final StoryEditorController controller;

  /// Canvas-to-screen conversion.
  final StoryViewportMapping mapping;

  @override
  State<StorySelectionLayer> createState() => _StorySelectionLayerState();
}

class _StorySelectionLayerState extends State<StorySelectionLayer> {
  static const double _rotateOffset = 48;

  Map<String, StoryTransform> _originals = const {};
  StoryPoint _center = StoryPoint.zero;
  StoryPoint _start = StoryPoint.zero;
  StoryHandleKind? _kind;

  StoryPoint _toCanvas(Offset global) {
    final box = context.findRenderObject();
    final local = box is RenderBox ? box.globalToLocal(global) : global;
    return widget.mapping.toCanvas(local);
  }

  void _begin(StoryHandleKind kind, Offset global) {
    final controller = widget.controller;
    final targets = controller.editableSelection;
    if (targets.isEmpty) return;
    _originals = {for (final e in targets) e.id: e.transform};
    _center = targets.length == 1
        ? targets.single.transform.position
        : (StoryElementGeometry.unionBounds(_originals.values)?.center ??
            StoryPoint.zero);
    _start = _toCanvas(global);
    _kind = kind;
    controller.beginTransaction(switch (kind) {
      StoryHandleKind.scale => 'Scale',
      StoryHandleKind.width || StoryHandleKind.height => 'Resize',
      StoryHandleKind.rotate => 'Rotate',
    });
  }

  void _update(Offset global) {
    final kind = _kind;
    if (kind == null || _originals.isEmpty) return;
    final controller = widget.controller;
    final point = _toCanvas(global);
    final minSize = controller.config.minElementSize;
    final Map<String, StoryTransform> next;
    switch (kind) {
      case StoryHandleKind.scale:
        final startDistance = StoryTransformMath.distance(_center, _start);
        if (startDistance == 0) return;
        next = StoryTransformMath.scaleAround(
          _originals,
          _center,
          StoryTransformMath.distance(_center, point) / startDistance,
          minSize: minSize,
        );
      case StoryHandleKind.rotate:
        var delta = StoryTransformMath.angleAround(_center, point) -
            StoryTransformMath.angleAround(_center, _start);
        final step = controller.config.rotationSnapDegrees;
        if (_originals.length == 1 && step > 0) {
          final original = _originals.values.single.rotation;
          delta =
              StorySnapping.snapRotation(original + delta, stepDegrees: step) -
                  original;
        }
        next = StoryTransformMath.rotateAround(_originals, _center, delta);
      case StoryHandleKind.width || StoryHandleKind.height:
        next = {
          for (final MapEntry(:key, value: t) in _originals.entries)
            key: StoryTransformMath.resizeEdge(
              t,
              horizontal: kind == StoryHandleKind.width,
              start: _start,
              current: point,
              minSize: minSize,
            ),
        };
    }
    controller.updateElements([
      for (final MapEntry(:key, value: transform) in next.entries)
        if (controller.elementById(key) case final element?)
          element.copyWithCommon(transform: transform),
    ]);
  }

  void _end() {
    if (_kind != null) widget.controller.commitTransaction();
    _reset();
  }

  void _cancel() {
    if (_kind != null) widget.controller.cancelTransaction();
    _reset();
  }

  void _reset() {
    _originals = const {};
    _kind = null;
  }

  @override
  void dispose() {
    if (_kind != null && !widget.controller.isDisposed) {
      widget.controller.cancelTransaction();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final mapping = widget.mapping;
    final selected = controller.selectedElements;
    if (selected.isEmpty || controller.editingTextId != null) {
      return const SizedBox.shrink();
    }
    final editable = controller.editableSelection;
    final outlines = [
      for (final e in selected)
        [
          for (final p in StoryElementGeometry.corners(e.transform))
            mapping.toScreen(p)
        ],
    ];

    final handles = <(StoryHandleKind, Offset, String)>[];
    if (editable.length == 1) {
      final t = editable.single.transform;
      for (final corner in StoryElementGeometry.corners(t)) {
        handles.add((StoryHandleKind.scale, mapping.toScreen(corner), 'Scale'));
      }
      handles
        ..add((
          StoryHandleKind.width,
          mapping.toScreen(StoryTransformMath.edgeHandle(t, horizontal: true)),
          'Resize width'
        ))
        ..add((
          StoryHandleKind.height,
          mapping.toScreen(StoryTransformMath.edgeHandle(t, horizontal: false)),
          'Resize height'
        ))
        ..add((
          StoryHandleKind.rotate,
          mapping.toScreen(StoryTransformMath.rotationHandle(
              t, mapping.toCanvasDistance(_rotateOffset))),
          'Rotate'
        ));
    } else if (editable.length > 1) {
      final bounds = StoryElementGeometry.unionBounds(
          [for (final e in editable) e.transform]);
      if (bounds != null) {
        final groupCorners = [
          StoryPoint(bounds.left, bounds.top),
          StoryPoint(bounds.right, bounds.top),
          StoryPoint(bounds.right, bounds.bottom),
          StoryPoint(bounds.left, bounds.bottom),
        ];
        outlines.add([for (final p in groupCorners) mapping.toScreen(p)]);
        for (final corner in groupCorners) {
          handles.add((
            StoryHandleKind.scale,
            mapping.toScreen(corner),
            'Scale selection'
          ));
        }
        handles.add((
          StoryHandleKind.rotate,
          mapping.toScreen(StoryPoint(bounds.center.x,
              bounds.top - mapping.toCanvasDistance(_rotateOffset))),
          'Rotate selection',
        ));
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _OutlinePainter(outlines)),
          ),
        ),
        for (final (kind, at, label) in handles)
          StoryTransformHandle(
            kind: kind,
            position: at,
            semanticLabel: label,
            onStart: (global) => _begin(kind, global),
            onUpdate: _update,
            onEnd: _end,
            onCancel: _cancel,
          ),
      ],
    );
  }
}

/// A draggable transform handle.
class StoryTransformHandle extends StatelessWidget {
  /// Creates a handle centered on [position] (layer coordinates).
  const StoryTransformHandle({
    required this.kind,
    required this.position,
    required this.semanticLabel,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    super.key,
  });

  /// Visible size; the touch target is twice as large.
  static const double size = 16;

  /// What dragging does.
  final StoryHandleKind kind;

  /// Center of the handle.
  final Offset position;

  /// Spoken by screen readers.
  final String semanticLabel;

  /// Drag started at a global position.
  final ValueChanged<Offset> onStart;

  /// Drag moved to a global position.
  final ValueChanged<Offset> onUpdate;

  /// Drag ended.
  final VoidCallback onEnd;

  /// Drag was interrupted.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    const target = size * 2.5;
    return Positioned(
      left: position.dx - target / 2,
      top: position.dy - target / 2,
      width: target,
      height: target,
      child: Semantics(
        label: semanticLabel,
        child: MouseRegion(
          cursor: kind == StoryHandleKind.rotate
              ? SystemMouseCursors.grab
              : SystemMouseCursors.precise,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => onStart(details.globalPosition),
            onPanUpdate: (details) => onUpdate(details.globalPosition),
            onPanEnd: (_) => onEnd(),
            onPanCancel: onCancel,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  shape: kind == StoryHandleKind.rotate
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  border: Border.all(color: _accent, width: 2),
                ),
                child: const SizedBox.square(dimension: size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.outlines);

  final List<List<Offset>> outlines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final points in outlines) {
      if (points.isEmpty) continue;
      canvas.drawPath(Path()..addPolygon(points, true), paint);
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) => true;
}

/// Alignment guides and the drag-selection rectangle.
class _GuideAndMarqueeLayer extends StatelessWidget {
  const _GuideAndMarqueeLayer({
    required this.controller,
    required this.mapping,
  });

  final StoryEditorController controller;
  final StoryViewportMapping mapping;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller.guides, controller.marquee]),
      builder: (context, _) => CustomPaint(
        painter: _GuidePainter(
          guides: controller.guides.value,
          marquee: controller.marquee.value,
          mapping: mapping,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.guides,
    required this.marquee,
    required this.mapping,
  });

  final List<StoryGuide> guides;
  final StoryRect? marquee;
  final StoryViewportMapping mapping;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = const Color(0xFFFF4FA3)
      ..strokeWidth = 1;
    final canvasRect = mapping.canvasRect;
    for (final guide in guides) {
      if (guide.axis == StoryGuideAxis.vertical) {
        final x = mapping.toScreen(StoryPoint(guide.position, 0)).dx;
        canvas.drawLine(Offset(x, canvasRect.top), Offset(x, canvasRect.bottom),
            guidePaint);
      } else {
        final y = mapping.toScreen(StoryPoint(0, guide.position)).dy;
        canvas.drawLine(Offset(canvasRect.left, y), Offset(canvasRect.right, y),
            guidePaint);
      }
    }
    final rect = marquee;
    if (rect != null) {
      final screen = Rect.fromPoints(
        mapping.toScreen(StoryPoint(rect.left, rect.top)),
        mapping.toScreen(StoryPoint(rect.right, rect.bottom)),
      );
      canvas
        ..drawRect(screen, Paint()..color = const Color(0x334C8DFF))
        ..drawRect(
          screen,
          Paint()
            ..color = _accent
            ..style = PaintingStyle.stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      oldDelegate.guides != guides ||
      oldDelegate.marquee != marquee ||
      oldDelegate.mapping != mapping;
}

/// Edits a text element in place, matching its position, rotation, and
/// style on screen. Typing is one undo step per editing session.
class StoryInlineTextEditor extends StatefulWidget {
  /// Creates an inline editor for [element].
  const StoryInlineTextEditor({
    required this.controller,
    required this.element,
    required this.mapping,
    super.key,
  });

  /// The editor.
  final StoryEditorController controller;

  /// The text element being edited.
  final TextElement element;

  /// Canvas-to-screen conversion.
  final StoryViewportMapping mapping;

  @override
  State<StoryInlineTextEditor> createState() => _StoryInlineTextEditorState();
}

class _StoryInlineTextEditorState extends State<StoryInlineTextEditor> {
  final FocusNode _focus = FocusNode(debugLabel: 'story inline text');
  TextEditingController? _text;
  bool _inTransaction = false;

  @override
  void initState() {
    super.initState();
    final text = widget.element.text;
    _text = TextEditingController(text: text)
      ..selection = TextSelection.collapsed(offset: text.length);
    _focus.addListener(_onFocusChanged);
    // `autofocus` is ignored when something in the scope already has focus
    // (the editor itself usually does), so ask for focus explicitly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _commit();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _text?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _finish();
  }

  void _changed(String value) {
    final controller = widget.controller;
    if (controller.isDisposed) return;
    if (!_inTransaction) {
      controller.beginTransaction('Edit text');
      _inTransaction = true;
    }
    controller.setText(widget.element.id, value);
  }

  void _commit() {
    if (_inTransaction && !widget.controller.isDisposed) {
      widget.controller.commitTransaction();
    }
    _inTransaction = false;
  }

  void _finish() {
    _commit();
    if (!widget.controller.isDisposed) widget.controller.endTextEditing();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    final element = widget.element;
    final mapping = widget.mapping;
    final t = element.transform;
    final center = mapping.toScreen(t.position);
    final width = t.scaledSize.width * mapping.scale;
    final height = t.scaledSize.height * mapping.scale;
    final factor = mapping.scale * t.scale;
    final style = element.style.toTextStyle().copyWith(
          fontSize: element.style.fontSize * factor,
          letterSpacing: element.style.letterSpacing * factor,
        );
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: t.rotation,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: _accent)),
          child: Align(
            alignment: element.align.toAlignment(),
            child: EditableText(
              controller: text,
              focusNode: _focus,
              autofocus: true,
              style: style,
              textAlign: element.align.toTextAlign(),
              cursorColor: _accent,
              backgroundCursorColor: const Color(0xFF888888),
              maxLines: null,
              onChanged: _changed,
              onEditingComplete: _finish,
            ),
          ),
        ),
      ),
    );
  }
}
