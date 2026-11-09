import 'story_gesture_event.dart';

/// Responds to gestures on a story surface.
///
/// **Dispatch.** For each discrete event (tap, double tap, long press start
/// or end), handlers are tried from highest [priority] to lowest (newest first
/// on ties). The first one whose [canHandle] returns `true` handles the event
/// and no other handler sees it.
///
/// **Drags.** The handler that handles a [StoryDragStartEvent] owns that drag:
/// it alone receives the drag's update and end events. If the drag is
/// interrupted (the pointer is lost, the viewer is removed, or the handler is
/// disabled mid-drag), the owner's [cancel] is called instead of an end event.
///
/// Handlers should be stateless where possible. Drag events carry the total
/// offset, so most handlers need no per-drag fields.
abstract class StoryGestureHandler {
  /// Const constructor for subclasses.
  const StoryGestureHandler();

  /// Unique identifier within a registry.
  String get id;

  /// Dispatch order; higher runs first. Built-in handlers use 0.
  int get priority => 0;

  /// The recognizers this handler needs.
  Set<StoryGestureKind> get kinds;

  /// Whether this handler wants [context]'s event.
  bool canHandle(StoryGestureContext context);

  /// Acts on [context]'s event. Called only after [canHandle] returned `true`,
  /// or for the update and end events of a drag this handler owns.
  void handle(StoryGestureContext context);

  /// Undoes any in-progress effect (such as a held pause) when a drag or
  /// long press this handler owns is interrupted.
  void cancel(StoryGestureContext context) {}
}
