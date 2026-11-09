# Architecture

Story Framework ships as **one package** (`story_framework`) with a modular
internal layout. Modules live under `lib/src/<module>/` and are exposed through
a small number of public entry points.

## Modules

| Module | Path | Status | Responsibility |
|---|---|---|---|
| Core | `lib/src/core/` | ✅ | Value types, sources, enums, errors, playback state, JSON utilities |
| Composition | `lib/src/composition/` | ✅ | Document model, elements, serialization, validation |
| Media | `lib/src/media/` | Contracts only | Media controller contracts; integrations come in Phase 6 |
| Engine | `lib/src/engine/` | ✅ | Headless playback controller, timeline, navigation, lifecycle |
| Configuration | `lib/src/configuration/` | Playback only | Immutable configuration objects |
| Rendering | `lib/src/rendering/` | ✅ | Renderer contract, registry, built-in renderers, item views |
| Viewer | `lib/src/viewer/` | Planned (Phase 4–5) | Default viewer UI, progress, overlays |
| Gestures | `lib/src/gestures/` | Planned (Phase 5) | Gesture registry and handlers |
| Animations | `lib/src/animations/` | Planned (Phase 5) | Transition registry and presets |
| Editor | `lib/src/editor/` | Planned (Phase 8–10) | Editor controller, canvas, tools, history |
| Export | `lib/src/export/` | Planned (Phase 11) | Exporter registry and pipeline |

Directories are created when their module is implemented, not before.

## Dependency direction

```text
core  ←  composition  ←  media contracts
                ↑
      engine ─┬─ viewer ─┐
              │          ├─ rendering ─ media integrations
      editor ─┴──────────┘
                ↑
             export (composition + rendering, never the viewer)
```

Rules (enforced by review; CI will gain an import check when more modules
exist):

1. `core` imports only `dart:*`, `package:meta`, and `package:collection`. No
   Flutter imports.
2. `composition` imports only `core`. No Flutter imports, so it works in
   background isolates and widget-free tests. (The package as a whole still
   depends on the Flutter SDK.)
3. `engine` must not import `viewer` or `editor`. It may use
   `package:flutter/foundation.dart` (for `ValueListenable`); only the optional
   `StoryAppLifecycleBinding` imports `package:flutter/widgets.dart`.
4. `editor` must not import `viewer` or `engine`.
5. `viewer` and `editor` share the composition model and rendering contracts.
6. `export` must not import `viewer`.
7. `rendering` imports `core`, `composition`, and Flutter widgets. It must not
   import `engine`, `viewer`, or `editor`, so the editor and exporter can use it
   without playback.
8. Media integrations implement `media` contracts; the engine never imports a
   concrete media package.
9. No circular imports between modules.

## Public and internal API

- Everything under `lib/src/` is private by convention. Consumers import only
  the entry points below.
- Entry points re-export the stable public surface:

  | Entry point | Exports |
  |---|---|
  | `story_framework.dart` | All public entry points |
  | `composition.dart` | `core` + `composition` |
  | `media.dart` | `composition.dart` + media contracts |
  | `engine.dart` | `media.dart` + playback controller, config, clock, events, lifecycle |
  | `rendering.dart` | `composition.dart` + renderers, registry, image resolver, item views |

- Helpers needed only inside the package (for example `JsonReader`,
  `freezeJsonMap`) are not exported.
- A type is exported only when a consumer needs it to use or extend the
  framework.

## Key design decisions

- **One shared composition model.** The editor writes `StoryDocument`s, the
  viewer plays them, the exporter renders them. There is no separate
  "playback model".
- **Immutable values.** Documents are trees of immutable objects. Edits create
  new nodes along the changed path and share everything else, which makes
  undo/redo and change detection cheap.
- **Sealed hierarchies** for elements, sources, backgrounds, durations, and
  stickers, so every consumer handles each case exhaustively. Extension is
  through `WidgetElement`, `CustomElement`, `CustomStorySource`,
  `CustomSticker`, and `CustomItemDuration`, all keyed by application-defined
  string identifiers.
- **Flutter-free core.** Colors and geometry use framework types
  (`StoryColor`, `StoryPoint`) converted to `dart:ui` types only at the
  rendering edge.
- **Constructor injection.** No global service locator. Collaborators (clocks,
  media factories, caches, loggers) are passed in with sensible defaults.
- **Descriptions, not resources.** Models describe media; they never own
  controllers, decoders, or connections. Resource ownership is defined by the
  media contracts (whoever creates a controller disposes it).
