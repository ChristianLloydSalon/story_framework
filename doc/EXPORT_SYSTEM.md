# Export system

`package:story_framework/export.dart` turns a `StoryDocument` into files. It
depends on composition and rendering, never on the viewer or the engine.

## Pipeline

```text
StoryExporterRegistry.export(document, config)
  ├─ config.check()              invalid frame rate, width, or item ids
  ├─ StoryDocumentValidator      when config.validate is true
  ├─ pick exporter               the most recently registered one that supports(config)
  └─ StoryExportJob              result future, progress (0–1), cancel()
```

Exporter failures are wrapped in `ExportException`. When a job is cancelled
its result completes with `StoryCancelledException`.

## Built-in exporters

| Exporter | Format | Output |
|---|---|---|
| `StoryDocumentExporter` | `document` | `<id>.story.json`, pretty-printed and versioned |
| `StoryPngExporter` | `png` | `<itemId>.png` for each item, at `config.width` pixels wide |
| `StoryVideoExporter` | `video` | Whatever your `StoryVideoEncoder` produces |

`StoryExportConfig.itemIds` limits an export to some of the items.

## Offscreen rendering

`StoryItemSnapshotter` renders an item with its own pipeline and build owner.
It doesn't need to be on screen or in a widget tree. It uses the same
renderer registry as the viewer, in `StoryRenderMode.export`. Images are
loaded before capture, so exports never show loading placeholders. Images
that fail to load are drawn in their error state, and the export still
succeeds.

Only one frame's image is alive at a time, so memory doesn't grow with the
number of items.

## Video

The package has no encoder dependency. Implement `StoryVideoEncoder` with
ffmpeg, a platform channel, or a web encoder:

```dart
final class MyEncoder implements StoryVideoEncoder {
  @override
  Future<void> begin({required int width, required int height,
      required int frameRate}) async { /* open the encoder */ }

  @override
  Future<void> addFrame(ByteData rgba, {int count = 1}) async {
    // rgba: width × height × 4 bytes. Repeat it `count` times (or set
    // the frame's duration to count / frameRate).
  }

  @override
  Future<StoryExportOutput> finish(List<StoryExportAudio> audio) async {
    // Mix each track at audio.start for audio.duration, starting
    // trimStart into the source, at audio.volume. Return the file.
  }

  @override
  Future<void> abort() async { /* delete partial output */ }
}
```

The exporter renders each item once and passes it with a frame count, so a
5-second item at 30 fps is one `addFrame(rgba, count: 150)` call. Video
elements appear as their poster. Decoding video frame by frame needs a
platform media pipeline, so an encoder that has one can do it in its own
exporter. The encoder is always aborted on failure or cancellation.

## Custom exporters

```dart
final class GifExporter implements StoryExporter {
  @override
  String get id => 'gif';

  @override
  bool supports(StoryExportConfig config) => config.format == StoryExportFormat.video;

  @override
  Future<StoryExportResult> export(StoryExportContext context) async {
    for (final item in context.items) {
      context.checkCancelled();
      // ...
    }
    return StoryExportResult([...]);
  }
}
```

Exporters registered later win, so you can replace a built-in exporter by
registering your own for the same format.
