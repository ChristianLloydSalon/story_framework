# Playback Engine

`StoryController` (`package:story_framework/engine.dart`) plays a
`StoryDocument` without any UI. The viewer is one consumer of it; headless
apps can drive it directly.

```dart
final controller = StoryController(
  document: document,
  config: const StoryPlaybackConfig(defaultItemDuration: Duration(seconds: 6)),
  mediaFactories: [myVideoFactory],          // optional
  durationProviders: {'quiz': QuizDuration()}, // optional
);
final lifecycle = StoryAppLifecycleBinding(controller); // pause in background

controller.events.listen((event) {
  if (event is StoryItemCompletedEvent) markSeen(event.location);
});
controller.play();

// Later:
lifecycle.dispose();
await controller.dispose();
```

## State and listening

- `state` is a `ValueListenable<StoryPlaybackState>` that notifies on every
  change, including progress ticks while playing.
- `select((s) => s.itemIndex)` returns a listenable that notifies only when the
  selected value changes, so progress ticks don't rebuild widgets that
  don't need them. Create it once and dispose it when done.
- `position` reads the live position between ticks.
- `events` emits moments: item started, item completed (played to the end, not
  skipped), group completed, playback completed, and errors.

## Status

| Status | Meaning |
|---|---|
| `idle` | Not started; navigation only moves the location |
| `loading` | The current item is resolving its duration or initializing media |
| `playing` | The timeline is advancing |
| `paused` | Held by a pause reason, or ended without auto-advance |
| `completed` | Past the last item (or group end with `continueToNextGroup: false`) |
| `error` | Failed under `StoryErrorPolicy.stop`; `play()` retries |

## Timing

The position is `anchor + (clock.now - anchorTime) × speed`. Pausing, seeking,
and speed changes re-anchor. Ticks (`StoryTicker`, default a 16 ms timer) only
decide how often state is republished, so delayed or dropped ticks never cause
drift. Inject `StoryClock` and `StoryTicker` for deterministic tests; the
viewer can supply a vsync ticker.

Item duration:

| Item timing | Resolved as |
|---|---|
| `null` | `config.defaultItemDuration` |
| `FixedItemDuration` | As given |
| `IndefiniteItemDuration` | Never ends |
| `CustomItemDuration` | `durationProviders[providerId].resolve(...)`; `null` = indefinite |
| `MediaItemDuration` | Media length within the trim range, capped by `maxDuration`; `fallback` when unknown or no media factory applies |

## Pause reasons

Playback runs only when no `StoryPauseReason` is active. `pause()`/`play()`
toggle `user`; `addPauseReason`/`removePauseReason` handle the others
(`modal`, `navigationOverlay`, `external`). `StoryAppLifecycleBinding` manages
`appBackground`, and the engine manages `buffering` from media snapshots.

Buffering holds the timeline but keeps the media playing so it can recover;
any other reason pauses the media too.

## Navigation

`next`, `previous`, `nextGroup`, `previousGroup`, `jumpTo`, `jumpToItem`, and
`seekTo` return immediately. Empty groups are skipped. `previous` on the first
item restarts it; `next` on the last item completes playback. Manual
navigation always crosses groups; `continueToNextGroup` only affects
automatic advancing.

## Media

For `MediaItemDuration` items, the first `StoryMediaControllerFactory` whose
`supports` accepts the driving element creates a controller, with asset
references already resolved. The engine:

- owns and disposes it (renderers read it through `currentMedia` and must not
  dispose it);
- applies speed, volume (0 when muted), and the trim start before playing;
- mirrors play, pause, seek, and speed;
- follows the reported media position (except for looping drivers, which stay
  on the clock and end after one media length);
- advances when the media completes;
- routes media errors to the error policy.

Other time-based elements in an item (for example background audio on a
fixed-duration item) and preloading arrive with media integrations (Phase 6).

## Asynchrony and cancellation

Each time the current item changes, a generation counter increments. Async work
(duration providers, media initialization, media commands) checks it before
applying results; stale results are dropped and stale media is disposed. Rapid
navigation therefore settles on the last target with no stale updates.

`dispose()` cancels everything, disposes media, and completes when media
disposal finishes. Afterwards, every method throws
`ControllerDisposedException`.

## Errors

| Policy | Behavior |
|---|---|
| `StoryErrorPolicy.stop` (default) | Enter `error` with `state.error` set; `play()` retries the item |
| `StoryErrorPolicy.skip` | Emit an error event and advance; stops in `error` if every item fails in a row |

Non-framework errors are wrapped in `PlaybackException` with the original as
`cause`. Failures while disposing media are reported through
`FlutterError.reportError`, never swallowed.
