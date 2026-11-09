import 'package:flutter/widgets.dart';

import '../core/contracts/story_playback_hold.dart';
import '../core/enums/story_enums.dart';
import '../core/models/playback_state.dart';
import '../engine/controller/story_controller.dart';
import '../engine/widgets/story_playback_selector.dart';

/// Builds an overlay's content.
typedef StoryOverlayBuilder = Widget Function(
    BuildContext context, StoryController controller);

/// Decides from the playback state whether an overlay is visible.
typedef StoryOverlayVisibility = bool Function(StoryPlaybackState state);

/// A layer drawn above the story content, such as a header, reaction bar,
/// caption, or sponsor badge.
///
/// Overlays are independent: each has its own placement, z-order,
/// visibility, interaction, and state. An interactive overlay sits above the
/// gesture layer, so touches on it are consumed by it and never navigate.
@immutable
final class StoryOverlay {
  /// Creates an overlay description.
  const StoryOverlay({
    required this.id,
    required this.builder,
    this.alignment = AlignmentDirectional.topCenter,
    this.padding = EdgeInsets.zero,
    this.constraints,
    this.zIndex = 0,
    this.respectSafeArea = true,
    this.interactive = true,
    this.pauseWhileTouched = false,
    this.visibleWhen,
    this.fadeDuration = const Duration(milliseconds: 200),
    this.onShow,
    this.onHide,
  });

  /// Unique id; also keeps the overlay's state across rebuilds.
  final String id;

  /// Builds the content.
  final StoryOverlayBuilder builder;

  /// Where the content sits in the viewer.
  final AlignmentGeometry alignment;

  /// Space around the content.
  final EdgeInsetsGeometry padding;

  /// Size limits for the content, for responsive layouts.
  final BoxConstraints? constraints;

  /// Paint order among overlays; higher is on top. Built-in progress, header,
  /// and footer use 100. Ties keep list order.
  final int zIndex;

  /// Whether the overlay avoids system UI in fullscreen layouts.
  final bool respectSafeArea;

  /// Whether the overlay receives touches. Non-interactive overlays let
  /// touches through to the gesture layer.
  final bool interactive;

  /// Whether touching the overlay holds playback with
  /// [StoryPauseReason.interaction] until the finger lifts.
  final bool pauseWhileTouched;

  /// Visibility rule, or `null` to always show. Captured when the overlay is
  /// first built.
  final StoryOverlayVisibility? visibleWhen;

  /// How long showing and hiding fade; zero under reduced motion.
  final Duration fadeDuration;

  /// Called after the overlay becomes visible (including the first time).
  final VoidCallback? onShow;

  /// Called after the overlay becomes hidden.
  final VoidCallback? onHide;
}

/// Stacks [overlays] above the story content in z-order.
class StoryOverlayLayer extends StatelessWidget {
  /// Creates an overlay layer.
  const StoryOverlayLayer({
    required this.controller,
    required this.overlays,
    this.useSafeArea = true,
    this.reduceMotion = false,
    super.key,
  });

  /// The controller passed to overlay builders.
  final StoryController controller;

  /// The overlays to show.
  final List<StoryOverlay> overlays;

  /// Whether overlays that ask for it are kept inside the safe area.
  final bool useSafeArea;

  /// Whether visibility changes happen without fading.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final ordered = overlays.indexed.toList()
      ..sort((a, b) {
        final byZ = a.$2.zIndex.compareTo(b.$2.zIndex);
        return byZ != 0 ? byZ : a.$1.compareTo(b.$1);
      });
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (_, overlay) in ordered)
          _StoryOverlayHost(
            key: ValueKey(('story-overlay', overlay.id)),
            overlay: overlay,
            controller: controller,
            useSafeArea: useSafeArea && overlay.respectSafeArea,
            reduceMotion: reduceMotion,
          ),
      ],
    );
  }
}

class _StoryOverlayHost extends StatelessWidget {
  const _StoryOverlayHost({
    required this.overlay,
    required this.controller,
    required this.useSafeArea,
    required this.reduceMotion,
    super.key,
  });

  final StoryOverlay overlay;
  final StoryController controller;
  final bool useSafeArea;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final constraints = overlay.constraints;
    Widget content = overlay.builder(context, controller);
    if (constraints != null) {
      content = ConstrainedBox(constraints: constraints, child: content);
    }
    if (overlay.pauseWhileTouched) {
      content = _TouchHold(controller: controller, child: content);
    }
    content = Padding(padding: overlay.padding, child: content);

    Widget placed = Align(alignment: overlay.alignment, child: content);
    if (useSafeArea) placed = SafeArea(child: placed);

    final rule = overlay.visibleWhen;
    if (rule == null) {
      return _OverlayVisibility(
        overlay: overlay,
        visible: true,
        reduceMotion: reduceMotion,
        child: placed,
      );
    }
    return StoryPlaybackSelector<bool>(
      controller: controller,
      selector: rule,
      child: placed,
      builder: (context, visible, child) => _OverlayVisibility(
        overlay: overlay,
        visible: visible,
        reduceMotion: reduceMotion,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Fades the overlay in and out, blocks touches while hidden, and reports
/// visibility changes.
class _OverlayVisibility extends StatefulWidget {
  const _OverlayVisibility({
    required this.overlay,
    required this.visible,
    required this.reduceMotion,
    required this.child,
  });

  final StoryOverlay overlay;
  final bool visible;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_OverlayVisibility> createState() => _OverlayVisibilityState();
}

class _OverlayVisibilityState extends State<_OverlayVisibility> {
  @override
  void initState() {
    super.initState();
    if (widget.visible) _notify(visible: true);
  }

  @override
  void didUpdateWidget(_OverlayVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _notify(visible: widget.visible);
  }

  void _notify({required bool visible}) {
    final callback = visible ? widget.overlay.onShow : widget.overlay.onHide;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.visible && widget.overlay.interactive;
    return IgnorePointer(
      ignoring: !interactive,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration:
            widget.reduceMotion ? Duration.zero : widget.overlay.fadeDuration,
        child:
            ExcludeSemantics(excluding: !widget.visible, child: widget.child),
      ),
    );
  }
}

/// Holds playback while a pointer is down on the child.
class _TouchHold extends StatefulWidget {
  const _TouchHold({required this.controller, required this.child});

  final StoryController controller;
  final Widget child;

  @override
  State<_TouchHold> createState() => _TouchHoldState();
}

class _TouchHoldState extends State<_TouchHold> {
  final Map<int, StoryPlaybackHold> _holds = {};

  void _down(PointerDownEvent event) {
    if (widget.controller.isDisposed) return;
    _holds[event.pointer] =
        widget.controller.acquirePause(StoryPauseReason.interaction);
  }

  void _up(PointerEvent event) => _holds.remove(event.pointer)?.release();

  @override
  void dispose() {
    for (final hold in _holds.values) {
      hold.release();
    }
    _holds.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: widget.child,
      );
}
