import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../configuration/viewer/story_viewer_config.dart';
import '../../core/enums/story_enums.dart';
import '../../engine/controller/story_controller.dart';

/// The viewer's default interactions, translated into controller commands.
///
/// | Input | Action |
/// |---|---|
/// | Tap the leading part (see `previousTapFraction`) | `previous()` |
/// | Tap elsewhere | `next()` |
/// | Press and hold | Pause until release |
/// | Swipe toward the leading/trailing edge | Next/previous group |
/// | Drag down past `dismissDistance` | [onDismiss] |
/// | Arrow keys, space, escape | Navigate, pause/resume, dismiss |
///
/// Every gesture also has a non-gesture alternative: screen readers get
/// "Previous story" and "Next story" buttons, and keyboards get shortcuts.
///
/// Drags hold playback with [StoryPauseReason.navigationOverlay] while the
/// finger is down.
class StoryViewerGestureLayer extends StatefulWidget {
  /// Creates the gesture layer for [controller].
  const StoryViewerGestureLayer({
    required this.controller,
    this.config = const StoryViewerConfig(),
    this.onDismiss,
    super.key,
  });

  /// The controller to command.
  final StoryController controller;

  /// Which interactions are enabled.
  final StoryViewerConfig config;

  /// Called when the user dismisses the viewer, if dismissing is allowed.
  final VoidCallback? onDismiss;

  @override
  State<StoryViewerGestureLayer> createState() =>
      _StoryViewerGestureLayerState();
}

class _StoryViewerGestureLayerState extends State<StoryViewerGestureLayer> {
  static const double _flingVelocity = 300;
  double _dragDistance = 0;

  StoryController get _controller => widget.controller;

  bool get _usable => !_controller.isDisposed;

  void _tap(TapUpDetails details) {
    if (!_usable) return;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final fromLeading =
        rtl ? width - details.localPosition.dx : details.localPosition.dx;
    if (fromLeading < width * widget.config.previousTapFraction) {
      _controller.previous();
    } else {
      _controller.next();
    }
  }

  void _holdStart(LongPressStartDetails details) {
    if (_usable) _controller.pause();
  }

  void _holdEnd(LongPressEndDetails details) {
    if (_usable) _controller.play();
  }

  void _dragStart(DragStartDetails details) {
    _dragDistance = 0;
    if (_usable) {
      _controller.addPauseReason(StoryPauseReason.navigationOverlay);
    }
  }

  void _verticalUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dy;
  }

  void _releaseDrag() {
    if (_usable) {
      _controller.removePauseReason(StoryPauseReason.navigationOverlay);
    }
  }

  void _verticalEnd(DragEndDetails details) {
    _releaseDrag();
    final dismiss = widget.onDismiss;
    final velocity = details.primaryVelocity ?? 0;
    if (dismiss != null &&
        (_dragDistance >= widget.config.dismissDistance ||
            velocity > _flingVelocity * 2)) {
      dismiss();
    }
  }

  void _horizontalUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dx;
  }

  void _horizontalEnd(DragEndDetails details) {
    _releaseDrag();
    if (!_usable) return;
    final velocity = details.primaryVelocity ?? 0;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    // Positive values move toward the trailing edge in reading direction.
    final towardTrailing = rtl ? -_dragDistance : _dragDistance;
    final flingTowardTrailing = rtl ? -velocity : velocity;
    if (towardTrailing < -48 || flingTowardTrailing < -_flingVelocity) {
      _controller.nextGroup();
    } else if (towardTrailing > 48 || flingTowardTrailing > _flingVelocity) {
      _controller.previousGroup();
    }
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
    final config = widget.config;
    final dismiss = widget.onDismiss;
    final canDismiss = dismiss != null && config.swipeDownToDismiss;
    final previousFlex = (config.previousTapFraction * 100).round();

    Widget layer = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _tap,
      onLongPressStart: config.longPressToPause ? _holdStart : null,
      onLongPressEnd: config.longPressToPause ? _holdEnd : null,
      onVerticalDragStart: canDismiss ? _dragStart : null,
      onVerticalDragUpdate: canDismiss ? _verticalUpdate : null,
      onVerticalDragEnd: canDismiss ? _verticalEnd : null,
      onVerticalDragCancel: canDismiss ? _releaseDrag : null,
      onHorizontalDragStart: config.swipeBetweenGroups ? _dragStart : null,
      onHorizontalDragUpdate:
          config.swipeBetweenGroups ? _horizontalUpdate : null,
      onHorizontalDragEnd: config.swipeBetweenGroups ? _horizontalEnd : null,
      onHorizontalDragCancel: config.swipeBetweenGroups ? _releaseDrag : null,
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

    if (config.keyboardShortcuts) {
      final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
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
