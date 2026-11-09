import 'package:flutter/widgets.dart';

import '../../core/models/geometry.dart';
import 'story_media_controller.dart';

/// A media controller that can display frames, such as a video player.
///
/// Renderers show the frames of the controller the playback engine is
/// already driving, so a video is never decoded twice.
abstract interface class StoryVisualMediaController
    implements StoryMediaController {
  /// The media's natural size, once known.
  StorySize? get naturalSize;

  /// A widget showing the current frame, filling its box.
  Widget buildView(BuildContext context);
}

/// Finds the live media controller for an element, or `null`.
typedef StoryMediaLookup = StoryMediaController? Function(String elementId);

/// Makes the playback engine's media controllers available to renderers
/// without the rendering layer depending on the engine.
///
/// The `changes` listenable notifies when the set of active controllers changes, so video
/// renderers rebuild when their controller becomes available.
class StoryMediaScope extends InheritedNotifier<Listenable> {
  /// Creates a scope.
  const StoryMediaScope({
    required this.lookup,
    required super.child,
    Listenable? changes,
    super.key,
  }) : super(notifier: changes);

  /// Finds the controller for an element id.
  final StoryMediaLookup lookup;

  /// The nearest scope, or `null`. Rebuilds the caller when media changes.
  static StoryMediaScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoryMediaScope>();

  @override
  bool updateShouldNotify(StoryMediaScope oldWidget) =>
      oldWidget.lookup != lookup || super.updateShouldNotify(oldWidget);
}
