## Unreleased

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
