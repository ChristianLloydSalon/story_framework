import 'package:flutter/widgets.dart';

import '../engine/controller/story_controller.dart';

/// The recognizers a gesture handler needs.
///
/// The gesture layer only installs recognizers that some enabled handler asks
/// for. For example, a double-tap recognizer delays single taps, so it is
/// added only when a handler wants double taps.
enum StoryGestureKind {
  /// A single tap.
  tap,

  /// Two quick taps.
  doubleTap,

  /// Press and hold.
  longPress,

  /// A horizontal drag.
  horizontalDrag,

  /// A vertical drag.
  verticalDrag,
}

/// The axis of a drag.
enum StoryDragAxis {
  /// Left and right.
  horizontal,

  /// Up and down.
  vertical,
}

/// A recognized gesture, in the gesture layer's local coordinates.
@immutable
sealed class StoryGestureEvent {
  const StoryGestureEvent();

  /// The recognizer that produced this event.
  StoryGestureKind get kind;
}

/// A single tap at [position].
final class StoryTapEvent extends StoryGestureEvent {
  /// Creates a tap event.
  const StoryTapEvent(this.position);

  /// Where the tap landed.
  final Offset position;

  @override
  StoryGestureKind get kind => StoryGestureKind.tap;
}

/// A double tap at [position].
final class StoryDoubleTapEvent extends StoryGestureEvent {
  /// Creates a double-tap event.
  const StoryDoubleTapEvent(this.position);

  /// Where the second tap landed.
  final Offset position;

  @override
  StoryGestureKind get kind => StoryGestureKind.doubleTap;
}

/// A press held long enough to count as a long press.
final class StoryLongPressStartEvent extends StoryGestureEvent {
  /// Creates a long-press start event.
  const StoryLongPressStartEvent(this.position);

  /// Where the press is.
  final Offset position;

  @override
  StoryGestureKind get kind => StoryGestureKind.longPress;
}

/// The end of a long press.
final class StoryLongPressEndEvent extends StoryGestureEvent {
  /// Creates a long-press end event.
  const StoryLongPressEndEvent(this.position);

  /// Where the finger lifted.
  final Offset position;

  @override
  StoryGestureKind get kind => StoryGestureKind.longPress;
}

/// Base class for the phases of a drag along [axis].
sealed class StoryDragEvent extends StoryGestureEvent {
  const StoryDragEvent(this.axis);

  /// The drag axis.
  final StoryDragAxis axis;

  @override
  StoryGestureKind get kind => axis == StoryDragAxis.horizontal
      ? StoryGestureKind.horizontalDrag
      : StoryGestureKind.verticalDrag;
}

/// A drag began at [position].
final class StoryDragStartEvent extends StoryDragEvent {
  /// Creates a drag start event.
  const StoryDragStartEvent(super.axis, this.position);

  /// Where the drag began.
  final Offset position;
}

/// A drag moved.
final class StoryDragUpdateEvent extends StoryDragEvent {
  /// Creates a drag update event.
  const StoryDragUpdateEvent(super.axis,
      {required this.delta, required this.offset});

  /// Movement along the axis since the previous update.
  final double delta;

  /// Total movement along the axis since the drag began.
  final double offset;
}

/// A drag ended.
final class StoryDragEndEvent extends StoryDragEvent {
  /// Creates a drag end event.
  const StoryDragEndEvent(super.axis,
      {required this.offset, required this.velocity});

  /// Total movement along the axis since the drag began.
  final double offset;

  /// Release velocity along the axis, in logical pixels per second.
  final double velocity;
}

/// Everything a handler needs to act on a gesture.
@immutable
final class StoryGestureContext {
  /// Creates a gesture context.
  const StoryGestureContext({
    required this.event,
    required this.controller,
    required this.size,
    this.textDirection = TextDirection.ltr,
    this.onDismiss,
  });

  /// The gesture.
  final StoryGestureEvent event;

  /// The playback controller to command.
  final StoryController controller;

  /// Size of the gesture layer.
  final Size size;

  /// Reading direction; leading and trailing sides depend on it.
  final TextDirection textDirection;

  /// Dismisses the viewer, if the viewer can be dismissed.
  final VoidCallback? onDismiss;

  /// Whether the layout reads right to left.
  bool get isRtl => textDirection == TextDirection.rtl;

  /// How far [position] is from the leading edge, as a fraction of the width.
  double leadingFraction(Offset position) {
    if (size.width <= 0) return 0;
    final fromLeft = position.dx / size.width;
    return isRtl ? 1 - fromLeft : fromLeft;
  }

  /// Converts a horizontal movement to the reading direction: positive values
  /// move toward the trailing edge.
  double towardTrailing(double horizontal) => isRtl ? -horizontal : horizontal;
}
