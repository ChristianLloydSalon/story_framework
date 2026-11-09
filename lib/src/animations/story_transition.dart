import 'package:flutter/widgets.dart';

import '../core/utilities/json.dart';

/// Whether navigation moved forward or backward in the document.
enum StoryTransitionDirection {
  /// To a later item or group.
  forward,

  /// To an earlier item or group.
  backward,
}

/// One frame of a transition between two items.
@immutable
final class StoryTransitionFrame {
  /// Creates a transition frame.
  const StoryTransitionFrame({
    required this.animation,
    required this.incoming,
    required this.outgoing,
    this.direction = StoryTransitionDirection.forward,
    this.textDirection = TextDirection.ltr,
    this.parameters = const {},
  });

  /// Runs from 0 (only [outgoing] visible) to 1 (only [incoming] visible),
  /// already shaped by the configured curve.
  final Animation<double> animation;

  /// The item being shown.
  final Widget incoming;

  /// The item being replaced.
  final Widget outgoing;

  /// Navigation direction.
  final StoryTransitionDirection direction;

  /// Reading direction; directional transitions mirror for right to left.
  final TextDirection textDirection;

  /// Transition-specific values from `StoryTransitionConfiguration`.
  final JsonMap parameters;

  /// `1` when moving toward the trailing edge on screen, `-1` otherwise.
  ///
  /// Forward in left-to-right layouts moves content left (new content enters
  /// from the right); right-to-left and backward navigation each flip it.
  double get sign {
    final forward = direction == StoryTransitionDirection.forward;
    final ltr = textDirection == TextDirection.ltr;
    return forward == ltr ? 1 : -1;
  }
}

/// Animates from one story item to the next.
///
/// A transition is a stateless, shareable recipe: [build] receives both items
/// and an animation, and returns a widget that shows the frame. Both items are
/// laid out at full size; the transition decides how to move, clip, fade, or
/// transform them.
///
/// The transition duration is independent of the item's display duration;
/// playback starts on the incoming item as soon as navigation happens.
abstract class StoryTransition {
  /// Const constructor for subclasses.
  const StoryTransition();

  /// Identifier used by `StoryTransitionConfiguration.type`.
  String get id;

  /// Builds [frame], which must show only `frame.incoming` when the animation
  /// reaches 1.
  Widget build(BuildContext context, StoryTransitionFrame frame);
}
