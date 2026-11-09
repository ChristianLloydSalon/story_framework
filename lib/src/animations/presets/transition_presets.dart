import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../story_transition.dart';

/// Every built-in transition, as registered by
/// `StoryTransitionRegistry.withDefaults`.
const List<StoryTransition> storyTransitionPresets = [
  StoryNoTransition(),
  StoryFadeTransition(),
  StorySlideTransition(),
  StoryScaleTransition(),
  StoryZoomTransition(),
  StoryCubeTransition(),
  StoryRevealTransition.horizontal(),
  StoryRevealTransition.vertical(),
];

/// Cuts straight to the incoming item.
final class StoryNoTransition extends StoryTransition {
  /// Creates the transition.
  const StoryNoTransition();

  @override
  String get id => 'none';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) =>
      frame.incoming;
}

/// Cross-fades to the incoming item.
final class StoryFadeTransition extends StoryTransition {
  /// Creates the transition.
  const StoryFadeTransition();

  @override
  String get id => 'fade';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) => Stack(
        fit: StackFit.expand,
        children: [
          frame.outgoing,
          FadeTransition(opacity: frame.animation, child: frame.incoming),
        ],
      );
}

/// Pushes the outgoing item off one edge while the incoming one slides in.
final class StorySlideTransition extends StoryTransition {
  /// Creates the transition.
  const StorySlideTransition();

  @override
  String get id => 'slide';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) {
    final sign = frame.sign;
    return Stack(
      fit: StackFit.expand,
      children: [
        SlideTransition(
          position: Tween(begin: Offset.zero, end: Offset(-sign, 0))
              .animate(frame.animation),
          child: frame.outgoing,
        ),
        SlideTransition(
          position: Tween(begin: Offset(sign, 0), end: Offset.zero)
              .animate(frame.animation),
          child: frame.incoming,
        ),
      ],
    );
  }
}

/// Grows the incoming item from slightly smaller while fading it in.
final class StoryScaleTransition extends StoryTransition {
  /// Creates the transition.
  const StoryScaleTransition();

  @override
  String get id => 'scale';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) => Stack(
        fit: StackFit.expand,
        children: [
          frame.outgoing,
          FadeTransition(
            opacity: frame.animation,
            child: ScaleTransition(
              scale:
                  Tween<double>(begin: 0.85, end: 1).animate(frame.animation),
              child: frame.incoming,
            ),
          ),
        ],
      );
}

/// Zooms the outgoing item toward the viewer as it fades away.
final class StoryZoomTransition extends StoryTransition {
  /// Creates the transition.
  const StoryZoomTransition();

  @override
  String get id => 'zoom';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) {
    final fadeOut = ReverseAnimation(frame.animation);
    return Stack(
      fit: StackFit.expand,
      children: [
        frame.incoming,
        FadeTransition(
          opacity: fadeOut,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.25).animate(frame.animation),
            child: frame.outgoing,
          ),
        ),
      ],
    );
  }
}

/// Rotates the two items like faces of a cube, the classic transition
/// between story groups.
final class StoryCubeTransition extends StoryTransition {
  /// Creates the transition.
  const StoryCubeTransition();

  @override
  String get id => 'cube';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) =>
      _CubeFrame(frame: frame);
}

class _CubeFrame extends AnimatedWidget {
  _CubeFrame({required this.frame}) : super(listenable: frame.animation);

  final StoryTransitionFrame frame;

  static Matrix4 _rotation(double radians) => Matrix4.identity()
    ..setEntry(3, 2, 0.0012)
    ..rotateY(radians);

  @override
  Widget build(BuildContext context) {
    final t = frame.animation.value;
    final sign = frame.sign;
    // The shared edge between the faces moves across the screen; each face
    // hinges on it.
    return Stack(
      fit: StackFit.expand,
      children: [
        FractionalTranslation(
          translation: Offset(-sign * t, 0),
          child: Transform(
            alignment: sign > 0 ? Alignment.centerRight : Alignment.centerLeft,
            transform: _rotation(sign * t * math.pi / 2),
            child: frame.outgoing,
          ),
        ),
        FractionalTranslation(
          translation: Offset(sign * (1 - t), 0),
          child: Transform(
            alignment: sign > 0 ? Alignment.centerLeft : Alignment.centerRight,
            transform: _rotation(-sign * (1 - t) * math.pi / 2),
            child: frame.incoming,
          ),
        ),
      ],
    );
  }
}

/// Wipes the incoming item over the outgoing one, horizontally from the
/// entering edge or vertically from the top.
final class StoryRevealTransition extends StoryTransition {
  /// Reveals from the edge the navigation comes from.
  const StoryRevealTransition.horizontal() : axis = Axis.horizontal;

  /// Reveals from the top.
  const StoryRevealTransition.vertical() : axis = Axis.vertical;

  /// The wipe direction.
  final Axis axis;

  @override
  String get id =>
      axis == Axis.horizontal ? 'horizontalReveal' : 'verticalReveal';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) => Stack(
        fit: StackFit.expand,
        children: [
          frame.outgoing,
          ClipRect(
            clipper: _RevealClipper(
              progress: frame.animation,
              axis: axis,
              fromEnd: frame.sign > 0,
            ),
            child: frame.incoming,
          ),
        ],
      );
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper({
    required this.progress,
    required this.axis,
    required this.fromEnd,
  }) : super(reclip: progress);

  final Animation<double> progress;
  final Axis axis;

  /// Whether the wipe starts at the right edge (horizontal only).
  final bool fromEnd;

  @override
  Rect getClip(Size size) {
    final t = progress.value.clamp(0.0, 1.0);
    if (axis == Axis.vertical) {
      return Rect.fromLTWH(0, 0, size.width, size.height * t);
    }
    final width = size.width * t;
    return fromEnd
        ? Rect.fromLTWH(size.width - width, 0, width, size.height)
        : Rect.fromLTWH(0, 0, width, size.height);
  }

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.axis != axis ||
      oldClipper.fromEnd != fromEnd;
}
