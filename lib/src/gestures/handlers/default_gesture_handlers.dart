import '../../core/enums/story_enums.dart';
import '../story_gesture_event.dart';
import '../story_gesture_handler.dart';

/// Taps on the leading part go to the previous item; taps elsewhere go to the
/// next one. Mirrored for right-to-left layouts.
final class StoryTapNavigationHandler extends StoryGestureHandler {
  /// Creates the handler; [previousFraction] is the share of the width, from
  /// the leading edge, that goes back.
  const StoryTapNavigationHandler({this.previousFraction = 0.3});

  /// Handler id.
  static const String handlerId = 'tap-navigation';

  /// Share of the width, from the leading edge, that goes back.
  final double previousFraction;

  @override
  String get id => handlerId;

  @override
  Set<StoryGestureKind> get kinds => const {StoryGestureKind.tap};

  @override
  bool canHandle(StoryGestureContext context) => context.event is StoryTapEvent;

  @override
  void handle(StoryGestureContext context) {
    final event = context.event;
    if (event is! StoryTapEvent) return;
    if (context.leadingFraction(event.position) < previousFraction) {
      context.controller.previous();
    } else {
      context.controller.next();
    }
  }
}

/// Pressing and holding pauses playback until release.
final class StoryHoldToPauseHandler extends StoryGestureHandler {
  /// Creates the handler.
  const StoryHoldToPauseHandler();

  /// Handler id.
  static const String handlerId = 'hold-to-pause';

  @override
  String get id => handlerId;

  @override
  Set<StoryGestureKind> get kinds => const {StoryGestureKind.longPress};

  @override
  bool canHandle(StoryGestureContext context) =>
      context.event is StoryLongPressStartEvent;

  @override
  void handle(StoryGestureContext context) {
    switch (context.event) {
      case StoryLongPressStartEvent():
        context.controller.pause();
      case StoryLongPressEndEvent():
        context.controller.play();
      case StoryTapEvent() || StoryDoubleTapEvent() || StoryDragEvent():
        break;
    }
  }

  @override
  void cancel(StoryGestureContext context) => context.controller.play();
}

/// Horizontal swipes move to the next or previous group.
///
/// Holds playback with [StoryPauseReason.navigationOverlay] during the drag.
final class StorySwipeGroupsHandler extends StoryGestureHandler {
  /// Creates the handler.
  const StorySwipeGroupsHandler({
    this.distance = 48,
    this.velocity = 300,
  });

  /// Handler id.
  static const String handlerId = 'swipe-groups';

  /// Minimum drag distance that changes groups.
  final double distance;

  /// Minimum fling velocity that changes groups.
  final double velocity;

  @override
  String get id => handlerId;

  @override
  Set<StoryGestureKind> get kinds => const {StoryGestureKind.horizontalDrag};

  @override
  bool canHandle(StoryGestureContext context) =>
      context.event is StoryDragStartEvent;

  @override
  void handle(StoryGestureContext context) {
    final controller = context.controller;
    switch (context.event) {
      case StoryDragStartEvent():
        controller.addPauseReason(StoryPauseReason.navigationOverlay);
      case StoryDragEndEvent(:final offset, velocity: final fling):
        controller.removePauseReason(StoryPauseReason.navigationOverlay);
        final moved = context.towardTrailing(offset);
        final flung = context.towardTrailing(fling);
        // Dragging content toward the leading edge reveals the next group.
        if (moved < -distance || flung < -velocity) {
          controller.nextGroup();
        } else if (moved > distance || flung > velocity) {
          controller.previousGroup();
        }
      case StoryDragUpdateEvent() ||
            StoryTapEvent() ||
            StoryDoubleTapEvent() ||
            StoryLongPressStartEvent() ||
            StoryLongPressEndEvent():
        break;
    }
  }

  @override
  void cancel(StoryGestureContext context) =>
      context.controller.removePauseReason(StoryPauseReason.navigationOverlay);
}

/// Dragging down dismisses the viewer, when it can be dismissed.
///
/// Holds playback with [StoryPauseReason.navigationOverlay] during the drag.
final class StorySwipeDismissHandler extends StoryGestureHandler {
  /// Creates the handler.
  const StorySwipeDismissHandler({this.distance = 120, this.velocity = 600});

  /// Handler id.
  static const String handlerId = 'swipe-dismiss';

  /// Downward drag distance that dismisses.
  final double distance;

  /// Downward fling velocity that dismisses.
  final double velocity;

  @override
  String get id => handlerId;

  @override
  Set<StoryGestureKind> get kinds => const {StoryGestureKind.verticalDrag};

  @override
  bool canHandle(StoryGestureContext context) =>
      context.onDismiss != null && context.event is StoryDragStartEvent;

  @override
  void handle(StoryGestureContext context) {
    final controller = context.controller;
    switch (context.event) {
      case StoryDragStartEvent():
        controller.addPauseReason(StoryPauseReason.navigationOverlay);
      case StoryDragEndEvent(:final offset, velocity: final fling):
        controller.removePauseReason(StoryPauseReason.navigationOverlay);
        if (offset >= distance || fling > velocity) context.onDismiss?.call();
      case StoryDragUpdateEvent() ||
            StoryTapEvent() ||
            StoryDoubleTapEvent() ||
            StoryLongPressStartEvent() ||
            StoryLongPressEndEvent():
        break;
    }
  }

  @override
  void cancel(StoryGestureContext context) =>
      context.controller.removePauseReason(StoryPauseReason.navigationOverlay);
}
