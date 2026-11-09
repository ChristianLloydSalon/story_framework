# Gesture System

Gestures on a story surface go through a `StoryGestureRegistry` of
`StoryGestureHandler`s. The viewer and the future editor each have their own
registry, so an editor drag can never trigger viewer navigation.

## Handler contract

```dart
abstract class StoryGestureHandler {
  String get id;                          // unique in a registry
  int get priority => 0;                  // higher runs first
  Set<StoryGestureKind> get kinds;        // recognizers it needs
  bool canHandle(StoryGestureContext context);
  void handle(StoryGestureContext context);
  void cancel(StoryGestureContext context) {}
}
```

`StoryGestureContext` provides the event, the `StoryController`, the layer
size, the text direction (`leadingFraction` and `towardTrailing` help with
right-to-left layouts), and `onDismiss`.

Events: `StoryTapEvent`, `StoryDoubleTapEvent`, `StoryLongPressStartEvent`,
`StoryLongPressEndEvent`, and `StoryDragStartEvent`/`UpdateEvent`/`EndEvent`
with an axis. Drag updates and ends carry the total offset, so handlers can
stay stateless.

## Dispatch and conflict resolution

- **Discrete events** (tap, double tap, long-press start) go to enabled
  handlers in order: highest `priority` first, newest registration first on
  ties. The first handler whose `kinds` include the event and whose
  `canHandle` returns `true` handles it; nobody else sees it.
- **Sequences.** The handler that handles a drag start or long-press start
  *owns* the sequence. Updates and the end event go only to the owner.
- **Cancellation.** If the sequence is interrupted (the pointer is lost, the
  viewer is removed, the registry is swapped, or the owner is disabled
  mid-gesture), the owner's `cancel` runs instead of the end event, so held
  pauses are always released.
- **Recognizers on demand.** The gesture layer installs only the recognizers
  that enabled handlers ask for. Registering a double-tap handler adds the
  double-tap recognizer, which delays single taps slightly; without one, taps
  fire immediately.
- **Nested interactions.** Widgets above the gesture layer (interactive
  overlays, buttons) win Flutter's hit test, so they consume their own
  gestures without navigating.

## Defaults

`StoryGestureRegistry.withDefaults()`:

| Id | Kind | Behavior |
|---|---|---|
| `tap-navigation` | tap | Leading `previousTapFraction` goes back, elsewhere forward (mirrored in RTL) |
| `hold-to-pause` | long press | Pause until release (or cancel) |
| `swipe-groups` | horizontal drag | Next/previous group; holds `navigationOverlay` during the drag |
| `swipe-dismiss` | vertical drag | Dismiss past `distance` or on a fast fling, only when dismissible |

When the viewer owns its registry, it builds these from `StoryViewerConfig`
(`previousTapFraction`, `dismissDistance`, and the `longPressToPause`,
`swipeBetweenGroups`, `swipeDownToDismiss` switches). A registry passed as
`gestureRegistry` is used as is.

## Customizing

```dart
final gestures = StoryGestureRegistry.withDefaults(handlers: [
  DoubleTapToLike(onLike: sendLike),    // adds a new gesture
]);
gestures.setEnabled('swipe-groups', enabled: false); // switch one off
gestures.replace(MyTapNavigation());    // same id: swap the behavior

StoryViewer(document: document, gestureRegistry: gestures);
```

You own a registry you create. Dispose it after the viewer.

## Not gesture-only

Screen readers get "Previous story", "Next story", and "Close" buttons, and
keyboards get arrow keys, space, and escape, independent of the registry.

Pinch-to-zoom is not built in. Flutter cannot run scale and pan recognizers
on the same detector, so zoomable content should handle pinch in its own
interactive overlay or renderer.
