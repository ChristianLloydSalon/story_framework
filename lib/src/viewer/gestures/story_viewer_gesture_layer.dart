import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/enums/story_enums.dart';
import '../../engine/controller/story_controller.dart';
import '../../gestures/story_gesture_event.dart';
import '../../gestures/story_gesture_handler.dart';
import '../../gestures/story_gesture_registry.dart';

/// Recognizes gestures over the story content and dispatches them to the
/// handlers in [registry].
///
/// Only recognizers requested by enabled handlers are installed (see
/// [StoryGestureKind]). Widgets stacked above this layer, such as interactive
/// overlays, receive pointer events first, so they consume their own gestures
/// without triggering navigation.
///
/// Every gesture also has a non-gesture alternative: screen readers get
/// "Previous story" and "Next story" buttons, and, when [keyboardShortcuts]
/// is on, arrow keys navigate (mirrored in right-to-left layouts), space
/// pauses or resumes, and escape dismisses.
class StoryViewerGestureLayer extends StatefulWidget {
  /// Creates the gesture layer.
  const StoryViewerGestureLayer({
    required this.controller,
    required this.registry,
    this.onDismiss,
    this.keyboardShortcuts = true,
    this.previousButtonFraction = 0.3,
    super.key,
  });

  /// The controller to command.
  final StoryController controller;

  /// The handlers that receive gestures.
  final StoryGestureRegistry registry;

  /// Dismisses the viewer, or `null` if it cannot be dismissed.
  final VoidCallback? onDismiss;

  /// Whether keyboard shortcuts are active.
  final bool keyboardShortcuts;

  /// Width share of the screen-reader "Previous story" button.
  final double previousButtonFraction;

  @override
  State<StoryViewerGestureLayer> createState() =>
      _StoryViewerGestureLayerState();
}

class _StoryViewerGestureLayerState extends State<StoryViewerGestureLayer> {
  /// The handler that owns the current long press or drag, if any.
  StoryGestureHandler? _owner;
  StoryDragAxis? _dragAxis;
  double _dragOffset = 0;
  Offset _doubleTapPosition = Offset.zero;

  StoryController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.registry.addListener(_onRegistryChanged);
  }

  @override
  void didUpdateWidget(StoryViewerGestureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry.removeListener(_onRegistryChanged);
      widget.registry.addListener(_onRegistryChanged);
      _cancelOwner();
    }
    if (oldWidget.controller != widget.controller) _cancelOwner();
  }

  @override
  void dispose() {
    widget.registry.removeListener(_onRegistryChanged);
    _cancelOwner();
    super.dispose();
  }

  void _onRegistryChanged() {
    final owner = _owner;
    if (owner != null && !widget.registry.isEnabled(owner.id)) _cancelOwner();
    setState(() {});
  }

  StoryGestureContext _contextFor(StoryGestureEvent event) =>
      StoryGestureContext(
        event: event,
        controller: _controller,
        size: context.size ?? Size.zero,
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        onDismiss: widget.onDismiss,
      );

  bool get _usable => mounted && !_controller.isDisposed;

  void _dispatch(StoryGestureEvent event) {
    if (_usable) widget.registry.dispatch(_contextFor(event));
  }

  void _start(StoryGestureEvent event) {
    _cancelOwner();
    if (_usable) _owner = widget.registry.dispatch(_contextFor(event));
  }

  void _continue(StoryGestureEvent event) {
    final owner = _owner;
    if (owner != null && _usable) owner.handle(_contextFor(event));
  }

  void _finish(StoryGestureEvent event) {
    _continue(event);
    _owner = null;
    _dragAxis = null;
  }

  void _cancelOwner() {
    final owner = _owner;
    final axis = _dragAxis;
    _owner = null;
    _dragAxis = null;
    if (owner == null || _controller.isDisposed) return;
    owner.cancel(StoryGestureContext(
      event: axis == null
          ? const StoryLongPressEndEvent(Offset.zero)
          : StoryDragEndEvent(axis, offset: _dragOffset, velocity: 0),
      controller: _controller,
      size: Size.zero,
      onDismiss: widget.onDismiss,
    ));
  }

  void _dragStart(StoryDragAxis axis, DragStartDetails details) {
    _dragAxis = axis;
    _dragOffset = 0;
    _start(StoryDragStartEvent(axis, details.localPosition));
  }

  void _dragUpdate(StoryDragAxis axis, DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _dragOffset += delta;
    _continue(StoryDragUpdateEvent(axis, delta: delta, offset: _dragOffset));
  }

  void _dragEnd(StoryDragAxis axis, DragEndDetails details) {
    _finish(StoryDragEndEvent(axis,
        offset: _dragOffset, velocity: details.primaryVelocity ?? 0));
  }

  void _togglePause() {
    if (!_usable) return;
    if (_controller.state.value.pauseReasons.contains(StoryPauseReason.user)) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  void _next() {
    if (_usable) _controller.next();
  }

  void _previous() {
    if (_usable) _controller.previous();
  }

  @override
  Widget build(BuildContext context) {
    final kinds = widget.registry.activeKinds;
    bool wants(StoryGestureKind kind) => kinds.contains(kind);
    final previousFlex =
        (widget.previousButtonFraction.clamp(0.05, 0.95) * 100).round();

    Widget layer = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: wants(StoryGestureKind.tap)
          ? (details) => _dispatch(StoryTapEvent(details.localPosition))
          : null,
      onDoubleTapDown: wants(StoryGestureKind.doubleTap)
          ? (details) => _doubleTapPosition = details.localPosition
          : null,
      onDoubleTap: wants(StoryGestureKind.doubleTap)
          ? () => _dispatch(StoryDoubleTapEvent(_doubleTapPosition))
          : null,
      onLongPressStart: wants(StoryGestureKind.longPress)
          ? (details) => _start(StoryLongPressStartEvent(details.localPosition))
          : null,
      onLongPressEnd: wants(StoryGestureKind.longPress)
          ? (details) => _finish(StoryLongPressEndEvent(details.localPosition))
          : null,
      onHorizontalDragStart: wants(StoryGestureKind.horizontalDrag)
          ? (details) => _dragStart(StoryDragAxis.horizontal, details)
          : null,
      onHorizontalDragUpdate: wants(StoryGestureKind.horizontalDrag)
          ? (details) => _dragUpdate(StoryDragAxis.horizontal, details)
          : null,
      onHorizontalDragEnd: wants(StoryGestureKind.horizontalDrag)
          ? (details) => _dragEnd(StoryDragAxis.horizontal, details)
          : null,
      onHorizontalDragCancel:
          wants(StoryGestureKind.horizontalDrag) ? _cancelOwner : null,
      onVerticalDragStart: wants(StoryGestureKind.verticalDrag)
          ? (details) => _dragStart(StoryDragAxis.vertical, details)
          : null,
      onVerticalDragUpdate: wants(StoryGestureKind.verticalDrag)
          ? (details) => _dragUpdate(StoryDragAxis.vertical, details)
          : null,
      onVerticalDragEnd: wants(StoryGestureKind.verticalDrag)
          ? (details) => _dragEnd(StoryDragAxis.vertical, details)
          : null,
      onVerticalDragCancel:
          wants(StoryGestureKind.verticalDrag) ? _cancelOwner : null,
      child: Row(
        children: [
          Expanded(
            flex: previousFlex,
            child: Semantics(
              button: true,
              label: 'Previous story',
              onTap: _previous,
              child: const SizedBox.expand(),
            ),
          ),
          Expanded(
            flex: 100 - previousFlex,
            child: Semantics(
              button: true,
              label: 'Next story',
              onTap: _next,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );

    if (widget.keyboardShortcuts) {
      final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
      final dismiss = widget.onDismiss;
      layer = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              rtl ? _previous : _next,
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              rtl ? _next : _previous,
          const SingleActivator(LogicalKeyboardKey.space): _togglePause,
          if (dismiss != null)
            const SingleActivator(LogicalKeyboardKey.escape): dismiss,
        },
        child: Focus(autofocus: true, child: layer),
      );
    }
    return layer;
  }
}
