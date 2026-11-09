# Domain Model

```text
StoryDocument
├── canvas: StoryCanvasConfiguration   (width, height, background, safe area)
├── assets: [StoryAsset]               (shared media, referenced by id)
└── groups: [StoryGroup]               (e.g. one per author)
    └── items: [StoryItem]             (one page each)
        ├── background?, duration?, transition?, playback overrides
        └── elements: [StoryElement]
```

## Coordinates

- All element geometry is in **canvas units**, origin at the canvas top-left,
  x right, y down. A 1080×1920 canvas looks identical on every screen because
  viewers and editors scale the whole canvas
  (`StoryCanvasConfiguration.scalingBehavior`).
- `StoryTransform.position` is the element's **center**. Rotation (radians,
  clockwise) and uniform `scale` apply around the center, so move, rotate, and
  scale are independent edits.
- Drawing stroke points are in the drawing element's local box: `(0, 0)` is the
  top-left of its unscaled size.

## Identifiers

| Id | Must be unique within |
|---|---|
| Group | Document |
| Item | Document |
| Element | Its item |
| Asset | Document |

Ids are opaque strings chosen by the application or editor. They are never
generated implicitly, so documents are deterministic and diffable.

## Elements

| Type id | Class | Notes |
|---|---|---|
| `image` | `ImageElement` | `source`, `fit` |
| `video` | `VideoElement` | `TimedMediaElement`: volume, mute, loop, trim |
| `audio` | `AudioElement` | `TimedMediaElement`; no visual box |
| `text` | `TextElement` | `StoryTextStyle`, alignment, background, padding |
| `sticker` | `StickerElement` | Emoji, image (optionally animated), or provider sticker |
| `shape` | `ShapeElement` | Rectangle, ellipse, line, triangle |
| `drawing` | `DrawingElement` | Editable vector strokes |
| `widget` | `WidgetElement` | App widget identified by `widgetType` + JSON `data` |
| `custom` | `CustomElement` | App element type with its own renderer/editor |
| *(other)* | `UnknownElement` | Type not known to this version; preserved verbatim |

Common fields: `id`, `transform`, `opacity`, `zIndex`, `visible`, `locked`,
`semanticLabel`, `metadata`, `customData`.

**Paint order** is `zIndex` ascending; ties keep list order
(`StoryItem.elementsInPaintOrder`).

`metadata` is for framework and tool annotations; `customData` is for the
application. Both must be JSON-compatible and are deeply frozen on construction.

## Sources

`NetworkStorySource`, `FileStorySource`, `AssetStorySource`,
`MemoryStorySource` (base64 when serialized), `StreamStorySource`
(runtime-only, not serializable), `CustomStorySource`, and
`ReferenceStorySource` (points at a `StoryAsset`; resolve with
`StoryDocument.resolveSource`).

Sources never carry credentials or headers. Authorization belongs to the host
application's media configuration so secrets are never saved into documents or
logs. `NetworkStorySource.toString()` omits query strings for the same reason.

## Item timing

| Duration | Behavior |
|---|---|
| `null` | Use the playback configuration default |
| `FixedItemDuration` | Fixed display time |
| `MediaItemDuration` | Follows a video/audio element (optionally capped, with a fallback) |
| `IndefiniteItemDuration` | Never auto-advances (interactive content) |
| `CustomItemDuration` | Resolved by an app-registered provider |

A transition's duration is independent of the item's display duration.

## Playback state

`StoryPlaybackState` is an immutable snapshot (group/item index, position,
duration, status, buffering, media status, active `StoryPauseReason`s, speed,
error). Playback resumes only when every pause reason is cleared; the engine
(Phase 2) owns the transitions.
