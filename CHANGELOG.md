## Unreleased

- Interactive content: `InteractiveElement` with `StoryPoll`, `StoryQuiz`,
  `StoryQuestion`, `StorySlider`, `StoryCountdown`, `StoryLink`,
  `StoryProductTag`, and `StoryCustomInteraction`, with serialization and
  validation. Unknown interaction kinds are preserved like unknown elements.
- `StoryInteractionController` holds runtime state (votes, results, ratings,
  replies, reminders) and reports `StoryInteractionEvent`s;
  `StoryInteractionScope` provides it to widgets.
- `StoryInteractiveRenderer` (registered by default) with accessible,
  keyboard-operable views, inert previews without a scope, and builders for
  custom interactions.
- The viewer draws interactive elements above the gesture layer so they
  never trigger navigation, and accepts `interactionController` and
  `onInteraction`.
- Counted playback holds: `StoryController.acquirePause` and
  `StoryPlaybackHold`; new `StoryPauseReason.interaction`. Overlay
  `pauseWhileTouched` now uses counted holds.
- `StoryItemView.elementFilter` and `paintBackground`;
  `StoryElement.isInteractive`.
- Example: poll and link stickers.
- Gesture system: `StoryGestureHandler` contract, `StoryGestureRegistry`
  with priorities, newest-first tie breaking, enable/disable, drag and
  long-press ownership, and cancellation; default tap, hold, swipe-groups,
  and swipe-dismiss handlers. Recognizers are installed only when a handler
  needs them.
- Transition system: `StoryTransition` contract, `StoryTransitionRegistry`,
  presets (`none`, `fade`, `slide`, `scale`, `zoom`, `cube`,
  `horizontalReveal`, `verticalReveal`), named curves, and
  `StoryTransitionSwitcher`, which keeps item state across transitions.
- Viewer item and group transitions (cube between groups by default),
  per-item transitions from the document, and reduced-motion support
  (`StoryMotionPreference`).
- Overlay system: `StoryOverlay` with alignment, padding, constraints,
  z-index, safe area, interactivity, touch-to-pause, state-driven visibility,
  and show/hide callbacks; `StoryOverlayLayer`. The built-in top bar and
  footer are overlays at z-index 100.
- `StoryViewer` accepts `gestureRegistry`, `transitionRegistry`, and
  `overlays`.
- `StoryTransitionConfiguration.preset` const constructor.
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
