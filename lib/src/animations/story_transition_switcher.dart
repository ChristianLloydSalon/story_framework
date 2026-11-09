import 'package:flutter/widgets.dart';

import '../core/utilities/json.dart';
import 'story_transition.dart';

/// Shows [child] and animates with [transition] whenever [childKey] changes.
///
/// Both the outgoing and incoming children keep their state during and after
/// the animation (they are reparented with global keys), so decoded images
/// and players are not recreated when the transition ends.
///
/// A `null` [transition] or a zero [duration] cuts immediately. A new change
/// during an animation starts a new transition from the current child.
class StoryTransitionSwitcher extends StatefulWidget {
  /// Creates a switcher.
  const StoryTransitionSwitcher({
    required this.childKey,
    required this.child,
    this.transition,
    this.duration = Duration.zero,
    this.curve = Curves.easeInOut,
    this.direction = StoryTransitionDirection.forward,
    this.parameters = const {},
    super.key,
  });

  /// Identifies [child]; a change starts a transition.
  final Object childKey;

  /// The current child.
  final Widget child;

  /// How to animate into a new child; `null` cuts.
  final StoryTransition? transition;

  /// Animation length.
  final Duration duration;

  /// Animation easing.
  final Curve curve;

  /// Navigation direction for directional transitions.
  final StoryTransitionDirection direction;

  /// Passed to the transition.
  final JsonMap parameters;

  @override
  State<StoryTransitionSwitcher> createState() =>
      _StoryTransitionSwitcherState();
}

class _StoryTransitionSwitcherState extends State<StoryTransitionSwitcher>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _curved;
  GlobalKey _incomingKey = GlobalKey();
  GlobalKey? _outgoingKey;
  Widget? _outgoing;
  StoryTransition? _transition;
  StoryTransitionDirection _direction = StoryTransitionDirection.forward;
  JsonMap _parameters = const {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(StoryTransitionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.childKey == widget.childKey) return;

    final controller = _controller;
    final transition = widget.transition;
    if (controller == null ||
        transition == null ||
        widget.duration <= Duration.zero) {
      _finishTransition();
      _incomingKey = GlobalKey();
      return;
    }

    _outgoing = oldWidget.child;
    _outgoingKey = _incomingKey;
    _incomingKey = GlobalKey();
    _transition = transition;
    _direction = widget.direction;
    _parameters = widget.parameters;
    _curved?.dispose();
    _curved = CurvedAnimation(parent: controller, curve: widget.curve);
    controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null) {
      setState(_finishTransition);
    }
  }

  void _finishTransition() {
    _outgoing = null;
    _outgoingKey = null;
    _transition = null;
    _curved?.dispose();
    _curved = null;
  }

  @override
  void dispose() {
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incoming = KeyedSubtree(key: _incomingKey, child: widget.child);
    final outgoing = _outgoing;
    final transition = _transition;
    final animation = _curved;
    if (outgoing == null || transition == null || animation == null) {
      return incoming;
    }
    return transition.build(
      context,
      StoryTransitionFrame(
        animation: animation,
        incoming: incoming,
        outgoing: KeyedSubtree(key: _outgoingKey, child: outgoing),
        direction: _direction,
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        parameters: _parameters,
      ),
    );
  }
}
