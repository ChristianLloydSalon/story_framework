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
