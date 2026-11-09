# Story Framework

A modular Flutter framework for creating, editing, composing, and playing
multimedia stories — the kind of experience found in Instagram Stories,
Snapchat, or WhatsApp Status — with no forced UI, backend, media provider, or
state-management library.

> **Status: early development (`0.1.0-dev`).** The shared composition model,
> serialization, validation, and the headless playback engine are
> implemented. The viewer, editor, and export pipeline are planned; see
> [Roadmap](#roadmap). APIs may change before 1.0.

## What works today

- **One shared document model** for the editor, viewer, and exporter:
  `StoryDocument` → `StoryGroup` → `StoryItem` → `StoryElement`.
- **Element types:** image, video, audio, text, sticker (emoji, image,
  provider), shape, freehand drawing (vector strokes), app widget, and custom.
- **Immutable values** with structural equality and `copyWith`.
- **Versioned JSON serialization** with migrations, precise error paths, and
  lossless preservation of element types from newer versions.
- **Validation** with error/warning severities, stable codes, and pluggable
  rules.
- **Media contracts** for plugging in any video or audio package.
- **Headless playback engine** (`StoryController`): drift-free timeline,
  navigation, independent pause reasons, speed, seeking, media-driven
  durations, lifecycle handling, and safe cancellation on rapid navigation.

## Install

```yaml
dependencies:
  story_framework: ^0.1.0-dev.1
```

## Quick look

```dart
import 'package:story_framework/composition.dart';

final document = StoryDocument(
  id: 'trip',
  canvas: StoryCanvasConfiguration.portrait, // 1080×1920
  groups: [
    StoryGroup(id: 'alice', title: 'Alice', items: [
      StoryItem(
        id: 'beach',
        duration: const FixedItemDuration(Duration(seconds: 5)),
        elements: [
          ImageElement(
            id: 'photo',
            transform: const StoryTransform(
              position: StoryPoint(540, 960), // center, canvas units
              size: StorySize(1080, 1920),
            ),
            source: NetworkStorySource(Uri.parse('https://example.com/a.jpg')),
            semanticLabel: 'Sunset over the beach',
          ),
          TextElement(
            id: 'caption',
            transform: const StoryTransform(
              position: StoryPoint(540, 300),
              size: StorySize(900, 160),
            ),
            text: 'Day one 🌴',
            zIndex: 1,
          ),
        ],
      ),
    ]),
  ],
);

// Validate.
const StoryDocumentValidator().validateOrThrow(document);

// Save and restore.
const codec = StoryDocumentCodec();
final json = codec.encodeToString(document);
final restored = codec.decodeFromString(json);
assert(restored == document);
```

### Headless playback

```dart
import 'package:story_framework/engine.dart';

final controller = StoryController(document: document);
final itemIndex = controller.select((state) => state.itemIndex);
itemIndex.addListener(() => print('Now showing item ${itemIndex.value}'));
controller.play();
// ... controller.next(), controller.pause(), controller.seekTo(...)
await controller.dispose();
```

## Entry points

| Import | Contents |
|---|---|
| `package:story_framework/story_framework.dart` | Everything public |
| `package:story_framework/composition.dart` | Documents, elements, serialization, validation (no widgets) |
| `package:story_framework/media.dart` | Media controller contracts |
| `package:story_framework/engine.dart` | Headless playback controller |

Viewer, editor, animation, and export entry points will be added with their
modules.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 | Package foundation, CI, architecture docs | ✅ |
| 1 | Core domain and composition model | ✅ |
| 2 | Headless playback engine | ✅ |
| 3 | Rendering foundation | Planned |
| 4–5 | Story viewer and customization | Planned |
| 6 | Media integrations and caching | Planned |
| 7 | Interactive content | Planned |
| 8–10 | Story editor, tools, timeline, undo/redo | Planned |
| 11 | Export pipeline | Planned |
| 12 | Production readiness | Planned |

## Documentation

- [Architecture](doc/ARCHITECTURE.md)
- [Domain model](doc/DOMAIN_MODEL.md)
- [Serialization and validation](doc/COMPOSITION_SYSTEM.md)
- [Playback engine](doc/PLAYBACK_ENGINE.md)
- [API design conventions](doc/API_DESIGN.md)
- [Contributing](CONTRIBUTING.md)
