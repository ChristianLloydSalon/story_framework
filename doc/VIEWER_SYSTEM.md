# Viewer System

`StoryViewer` (`package:story_framework/viewer.dart`) is the presentation layer
over `StoryController`. It renders the current item with `StoryItemView`,
draws progress, and turns gestures into controller commands. All timing and
navigation logic stays in the controller.

```dart
StoryViewer(
  document: document,
  initialLocation: const StoryItemLocation(groupIndex: 2, itemIndex: 0),
  playbackConfig: const StoryPlaybackConfig(defaultItemDuration: Duration(seconds: 6)),
  config: const StoryViewerConfig(layout: StoryViewerLayout.fullscreen),
  footerBuilder: (context, controller) => ReplyBar(controller: controller),
  onDismiss: () => Navigator.pop(context),
  onComplete: () => Navigator.pop(context),
)
```

## Controller ownership

| Constructor | Controller |
|---|---|
| `StoryViewer(document: ...)` | Created, owned, and disposed by the viewer, using `playbackConfig`, `mediaFactories`, `durationProviders`, and `initialLocation` |
| `StoryViewer.controller(controller: ...)` | Yours; dispose it after the viewer |

The renderer registry follows the same rule: pass `registry` to share your
own, or the viewer creates the built-in one and disposes it.

## Parts and customization

| Part | Default | Replace with |
|---|---|---|
| Content | `StoryItemView` of the current item | `registry`, `renderOptions` |
| Interactive content | Interactive elements, above the gesture layer | `interactionController`, `onInteraction` |
| Progress | `StoryProgressBar` | `progressBuilder` |
| Header | `StoryViewerHeader` (group title, close button when `onDismiss` is set) | `headerBuilder` |
| Footer | none | `footerBuilder` |
| Loading/buffering | `StoryLoadingIndicator` | `loadingBuilder` |
| Error | `StoryViewerErrorView` with retry | `errorBuilder` |
| Arrangement | `StoryViewerDefaultLayout` | `layoutBuilder` (receives `StoryViewerParts`) |

Builders receive the `StoryController`, so custom parts can read state and
send commands. Use `StoryPlaybackSelector` inside them to rebuild only when
the value you show changes:

```dart
headerBuilder: (context, controller) => StoryPlaybackSelector<int>(
  controller: controller,
  selector: (state) => state.groupIndex,
  builder: (context, groupIndex, _) => AuthorHeader(groupIndex),
),
```

## Interactions

| Input | Action | Setting |
|---|---|---|
| Tap the leading 30% | `previous()` | `previousTapFraction` |
| Tap elsewhere | `next()` | |
| Press and hold | Pause until release | `longPressToPause` |
| Swipe toward the leading/trailing edge | Next/previous group | `swipeBetweenGroups` |
| Drag down | `onDismiss` | `swipeDownToDismiss`, `dismissDistance` |
| → / ← | Next/previous (mirrored in RTL) | `keyboardShortcuts` |
| Space | Pause/resume | `keyboardShortcuts` |
| Esc | `onDismiss` | `keyboardShortcuts` |

Tap zones and arrow keys mirror in right-to-left locales. Drags hold playback
with `StoryPauseReason.navigationOverlay` while the finger is down. Screen
readers get "Previous story", "Next story", and "Close" buttons, so no action
depends only on gestures.

The touch gestures are handlers in a `StoryGestureRegistry`. Pass
`gestureRegistry` to add, replace, or disable them (see
[GESTURE_SYSTEM.md](GESTURE_SYSTEM.md)). Transitions between items and groups
come from `transitionRegistry` and the config (see
[TRANSITION_SYSTEM.md](TRANSITION_SYSTEM.md)), and app layers go in
`overlays` (see [OVERLAY_SYSTEM.md](OVERLAY_SYSTEM.md)).

## Performance

- Progress ticks repaint the progress bar through a `CustomPainter` that
  listens to the controller directly. No widget rebuilds per tick.
- Content rebuilds only when the group or item changes; the header only when
  the group changes; the status overlay only when status, buffering, or error
  change.
- Each item view is keyed by group and item id, so element state (decoded
  images, for example) is kept until the item changes.

## Lifecycle

With `pauseInBackground` (default on), the viewer installs a
`StoryAppLifecycleBinding`, so playback holds with
`StoryPauseReason.appBackground` while the app is inactive, hidden, or paused.
With `autoplay` (default on), the viewer calls `play()` when it attaches to an
idle controller.

## Layouts

`StoryViewerLayout.fullscreen` keeps the top and bottom overlays inside the
safe area. `StoryViewerLayout.inline` uses the viewer's own bounds, for
embedding in feeds or cards. The canvas always scales by
`StoryCanvasConfiguration.scalingBehavior`, letterboxed on
`StoryViewerConfig.backgroundColor`.
