## Unreleased

- `StoryViewer`: plays a document with a segmented progress bar, header
  (group title and close button), optional footer, loading/buffering and error
  overlays with retry, and fullscreen or inline layouts.
- Viewer navigation: tap zones (mirrored for right-to-left), press-and-hold to
  pause, horizontal swipes between groups, swipe down to dismiss, keyboard
  shortcuts, and screen-reader buttons.
- `StoryViewerConfig`; builders for every part and a `layoutBuilder` to
  replace the arrangement; `StoryViewerParts` and `StoryViewerDefaultLayout`.
- Viewer-owned or external controllers, `initialLocation`, background pausing,
  and `onComplete`/`onDismiss` callbacks.
- Progress ticks repaint only the progress bar; content rebuilds only when the
  item changes.
- `StoryController.select` now returns a disposable `StorySelection`;
  `StoryPlaybackSelector` rebuilds widgets from one slice of playback state.
- Example app.
- Rendering foundation: `StoryElementRenderer` contract, `StoryRenderContext`,
  and `StoryRendererRegistry` (duplicate checks, explicit replacement,
  ownership-aware unregistering, change notification).
- `StoryItemView` renders an item on a scaled canvas with element transforms,
  opacity, z-order, and semantics labels.
- Built-in renderers for image, text (with outline stroke), sticker, shape,
  drawing, and audio elements, plus `StoryWidgetElementRenderer` and
  `StoryCustomElementRenderer` for app content.
- `StoryRenderOptions` with loading, error, and unsupported builders, error
  reporting, and text scaling.
- `DefaultStoryImageResolver` with HTTP headers and custom source resolvers;
  web-safe file image loading.
- The engine now defers media disposal to a microtask, so it never disposes a
  media controller from inside that controller's own event callback.
- Headless playback engine: `StoryController` with a clock-derived (drift-free)
  timeline, navigation across items and groups, seeking, playback speed,
  independent pause reasons, auto-advance, looping, and completion handling.
- `StoryPlaybackConfig` and `StoryErrorPolicy`.
- Media-driven item durations: trims, caps, fallbacks, buffering, and media
  completion, using injected `StoryMediaControllerFactory`s.
- `StoryDurationProvider` for `CustomItemDuration`.
- Playback events (item started/completed, group completed, playback
  completed, error).
- `StoryController.select` for granular listening.
- Injectable `StoryClock` and `StoryTicker`.
- `StoryAppLifecycleBinding` pauses playback while the app is in the
  background.
- Stale asynchronous work is discarded and its media disposed on navigation
  and disposal.

## 0.1.0-dev.1

Initial development release.

- Core value types: `StoryPoint`, `StorySize`, `StoryRect`, `StoryInsets`,
  `StoryColor`.
- Media sources: network, file, asset, memory, stream (runtime-only), custom,
  and document asset references.
- Composition model: `StoryDocument`, `StoryGroup`, `StoryItem`, and the sealed
  `StoryElement` hierarchy (image, video, audio, text, sticker, shape, drawing,
  widget, custom, unknown).
- Item timing: fixed, media-driven, indefinite, and custom durations;
  transition configuration.
- `StoryPlaybackState` snapshot and pause reasons.
- Versioned JSON serialization (`StoryDocumentCodec`) with migrations and an
  unknown-element policy.
- `StoryDocumentValidator` with pluggable rules.
- Typed exception hierarchy rooted at `StoryException`.
- Media controller contracts.
