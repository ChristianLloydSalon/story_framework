import 'package:flutter/widgets.dart';

import '../../core/models/playback_state.dart';
import '../controller/story_controller.dart';
import '../state/story_selection.dart';

/// Builds a widget from one derived value of a controller's playback state.
typedef StoryPlaybackSelectorBuilder<T> = Widget Function(
    BuildContext context, T value, Widget? child);

/// Rebuilds only when the value picked by [selector] changes.
///
/// Use it to keep progress ticks from rebuilding widgets that only care about,
/// for example, the current group:
///
/// ```dart
/// StoryPlaybackSelector<int>(
///   controller: controller,
///   selector: (state) => state.groupIndex,
///   builder: (context, groupIndex, _) => AuthorBadge(groupIndex),
/// )
/// ```
///
/// [selector] is captured when the controller is first attached; changing it
/// later has no effect unless the [controller] also changes.
class StoryPlaybackSelector<T> extends StatefulWidget {
  /// Creates a selector widget.
  const StoryPlaybackSelector({
    required this.controller,
    required this.selector,
    required this.builder,
    this.child,
    super.key,
  });

  /// The controller whose state is observed.
  final StoryController controller;

  /// Picks the value to watch; compared with `==`.
  final T Function(StoryPlaybackState state) selector;

  /// Builds the widget for the current value.
  final StoryPlaybackSelectorBuilder<T> builder;

  /// A subtree passed through to [builder] that does not depend on the value.
  final Widget? child;

  @override
  State<StoryPlaybackSelector<T>> createState() =>
      _StoryPlaybackSelectorState<T>();
}

class _StoryPlaybackSelectorState<T> extends State<StoryPlaybackSelector<T>> {
  StorySelection<T>? _selection;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(StoryPlaybackSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    if (widget.controller.isDisposed) return;
    final selection = widget.controller.select(widget.selector)
      ..addListener(_onChanged);
    _selection = selection;
  }

  void _detach() {
    final selection = _selection;
    if (selection == null) return;
    selection
      ..removeListener(_onChanged)
      ..dispose();
    _selection = null;
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    final value = selection == null
        ? widget.selector(widget.controller.state.value)
        : selection.value;
    return widget.builder(context, value, widget.child);
  }
}
