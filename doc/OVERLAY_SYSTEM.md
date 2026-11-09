# Overlay System

Overlays are independently composed layers above the story content:
reaction bars, captions, sponsor badges, pause indicators, and the viewer's
own top bar and footer.

```dart
StoryViewer(
  document: document,
  overlays: [
    StoryOverlay(
      id: 'reactions',
      alignment: AlignmentDirectional.bottomEnd,
      padding: const EdgeInsets.all(16),
      pauseWhileTouched: true,
      builder: (context, controller) => ReactionButton(controller: controller),
    ),
    StoryOverlay(
      id: 'paused',
      alignment: AlignmentDirectional.center,
      interactive: false,
      visibleWhen: (state) => state.pauseReasons.contains(StoryPauseReason.user),
      builder: (context, controller) => const PausedBadge(),
    ),
  ],
)
```

## Options

| Option | Purpose |
|---|---|
| `id` | Unique key; keeps the overlay's state across rebuilds |
| `builder` | Builds the content, with the `StoryController` |
| `alignment`, `padding` | Position in the viewer |
| `constraints` | Size limits for responsive layouts |
| `zIndex` | Paint order (ties keep list order) |
| `respectSafeArea` | Avoid system UI in fullscreen layouts |
| `interactive` | Whether it receives touches. Non-interactive overlays pass touches to the gesture layer |
| `pauseWhileTouched` | Hold playback with `StoryPauseReason.interaction` while pressed (counted, so it never releases another widget's hold) |
| `visibleWhen` | Show or hide from the playback state, with a fade (`fadeDuration`, zero under reduced motion) |
| `onShow`, `onHide` | Called after visibility changes (and on first show) |

Hidden overlays ignore touches and are excluded from semantics.

## Z-order and the built-ins

The default layout composes the built-in top bar (`story.top`: progress and
header) and footer (`story.footer`) as overlays with z-index 100. App
overlays with a lower z-index sit beneath them; higher ones sit on top.

## Gestures

An interactive overlay sits above the gesture layer, so taps on it are
consumed by the overlay and never navigate. Taps on empty space around it
still reach the gesture layer.

## Custom layouts

`StoryViewerParts.overlays` carries the app overlays to a `layoutBuilder`.
Place them with `StoryOverlayLayer`:

```dart
layoutBuilder: (context, parts) => Stack(children: [
  parts.content,
  parts.gestures,
  StoryOverlayLayer(controller: parts.controller, overlays: parts.overlays),
]),
```
