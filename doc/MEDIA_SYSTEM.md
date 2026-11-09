# Media System

`story_framework` has **no player dependency**. It defines media contracts;
your app plugs in any player with a small adapter.

## Plugging in a player

| Contract | Implement it for |
|---|---|
| `StoryMediaController` | Any time-based media (audio, video) |
| `StoryVisualMediaController` | Media with frames (video): adds `naturalSize` and `buildView` |
| `StoryMediaControllerFactory` | Choosing which elements a player handles and creating controllers |

Ready-made adapters to copy live in the example app:

| File | Player | Elements |
|---|---|---|
| [`example/lib/media/video_player_adapter.dart`](../example/lib/media/video_player_adapter.dart) | `video_player` | `VideoElement` |
| [`example/lib/media/just_audio_adapter.dart`](../example/lib/media/just_audio_adapter.dart) | `just_audio` | `AudioElement` |

```dart
StoryViewer(
  document: document,
  mediaFactories: const [
    VideoPlayerStoryMediaFactory(),
    JustAudioStoryMediaFactory(),
  ],
)
```

### Adapter rules

- **`initialize()` is idempotent.** Concurrent calls share one
  initialization, so the engine can preload a controller and adopt it later.
- **Emit only meaningful snapshots.** Publish status changes immediately and
  throttle position-only updates (the adapters use 250 ms); the engine
  interpolates the timeline between them. Never emit identical snapshots.
- **Publish your ready state** after initialization, and `disposed` on
  `dispose()`.
- **The creator owns the controller.** The engine creates, adopts, and
  disposes controllers. Renderers only display them.

## What the engine does with media

| Media | Behavior |
|---|---|
| Duration-driving element (`MediaItemDuration`) | Sets the item's length (trims, caps, fallback); the timeline follows its position; buffering holds the timeline; completion advances |
| Companion elements (other videos and audio on the item) | Play, pause, seek, and change speed with the timeline; loop and trim end are honored; failures are reported as `StoryPlaybackErrorEvent`s but never stop the story |
| Next item | With `StoryPlaybackConfig.mediaPreload: next` (default), its controllers are created and initialized ahead of time, then adopted on arrival so playback starts without a loading pause |

**Resource bounds:**

- At most `StoryPlaybackConfig.maxActiveMedia` controllers per item (default
  3), with the duration-driving one first.
- Preloading covers only the single next item, within the same budget.
- Skipping past a preloaded item disposes its controllers.
- `dispose()` releases everything and waits for player disposal.
- Disposal is deferred to a microtask, so a controller is never disposed
  from inside its own event callback.

Renderers find live controllers through `StoryMediaScope`, which the viewer
installs over `StoryController.mediaFor`. The rendering layer never imports
the engine.

## Video rendering

`StoryVideoRenderer` (registered by default) shows the frames of the
controller the engine is already driving, so a video is decoded once. It
rebuilds only when the media **status** changes, never on position updates.

| Situation | Shown |
|---|---|
| Playing or paused in the viewer | Frames, fitted with the element's `fit` |
| Loading | The element's `poster` image, or the loading placeholder |
| Media failed | The error state (`StoryRenderOptions.errorBuilder`) |
| No engine (editor, export, thumbnails) | The `poster`, or a ▶ placeholder |
| No engine, with `StoryRenderOptions.previewMediaFactories` | A live, muted first frame from a preview controller the view owns |

Live previews create a controller per visible video, so enable them only
where few videos are on screen (for example the editor canvas, not
thumbnails).

## Images: prefetching and caching

**Prefetching.** The viewer decodes the next item's images (image elements,
image stickers, video posters, media backgrounds) after the current item has
rendered. It is bounded to one item and runs once per item. Decoded images
live in Flutter's `ImageCache`.

**Byte caching (optional).** Give `DefaultStoryImageResolver` a
`StoryResourceLoader` to keep encoded image bytes even after the `ImageCache`
evicts the decoded image:

```dart
final loader = StoryResourceLoader(
  fetcher: createStoryHttpFetcher(headersFor: (url) => authHeaders),
  cache: MemoryStoryCache(maxBytes: 64 * 1024 * 1024, timeToLive: const Duration(hours: 1)),
);

StoryViewer(
  document: document,
  renderOptions: StoryRenderOptions(
    imageResolver: DefaultStoryImageResolver(networkLoader: loader),
  ),
)
```

| Piece | Behavior |
|---|---|
| `MemoryStoryCache` | LRU eviction bounded by total bytes and entry count; optional time to live; entries larger than the cache are skipped |
| `StoryCacheProvider` | Contract for your own cache (for example disk via `flutter_cache_manager`) |
| `StoryResourceLoader` | Cache first; concurrent loads of a key share one fetch; failures are not cached; at most `maxConcurrentFetches` fetches at once |
| `StoryCancellationToken` | A cancelled caller stops waiting at once; the fetch itself is aborted when no caller is left |
| `createStoryHttpFetcher` | `dart:io` HTTP fetcher with headers and abort on cancel (on the web, supply your own; the browser cache applies) |
| `StoryCachedImageProvider` | An `ImageProvider` that loads through the loader |
