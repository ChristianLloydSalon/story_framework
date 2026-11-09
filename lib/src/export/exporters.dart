import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../composition/elements/story_element.dart';
import '../composition/items/item_timing.dart';
import '../composition/items/story_item.dart';
import '../composition/serialization/story_document_codec.dart';
import '../core/errors/story_exceptions.dart';
import '../core/models/story_source.dart';
import 'story_export.dart';
import 'story_item_snapshot.dart';

/// Exports the serialized document as JSON.
final class StoryDocumentExporter implements StoryExporter {
  /// Creates the exporter.
  const StoryDocumentExporter({this.codec = const StoryDocumentCodec()});

  /// The codec used.
  final StoryDocumentCodec codec;

  @override
  String get id => 'document';

  @override
  bool supports(StoryExportConfig config) =>
      config.format == StoryExportFormat.document;

  @override
  Future<StoryExportResult> export(StoryExportContext context) async {
    context.checkCancelled();
    final json = codec.encodeToString(context.document, pretty: true);
    return StoryExportResult([
      StoryExportOutput(
        name: '${context.document.id}.story.json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(utf8.encode(json)),
      ),
    ]);
  }
}

/// Exports one PNG per item, rendered offscreen at the configured width.
///
/// Images are rendered one at a time and released immediately, so memory
/// stays bounded by a single frame regardless of how many items there are.
final class StoryPngExporter implements StoryExporter {
  /// Creates the exporter.
  StoryPngExporter({StoryItemSnapshotter? snapshotter})
      : snapshotter = snapshotter ?? StoryItemSnapshotter();

  /// Renders items.
  final StoryItemSnapshotter snapshotter;

  @override
  String get id => 'png';

  @override
  bool supports(StoryExportConfig config) =>
      config.format == StoryExportFormat.png;

  @override
  Future<StoryExportResult> export(StoryExportContext context) async {
    final items = context.items;
    final outputs = <StoryExportOutput>[];
    for (final (index, item) in items.indexed) {
      context.checkCancelled();
      final image = await snapshotter.capture(context.document, item,
          width: context.width);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const ExportException('PNG encoding failed');
        outputs.add(StoryExportOutput(
          name: '${item.id}.png',
          mimeType: 'image/png',
          bytes: data.buffer.asUint8List(),
        ));
      } finally {
        image.dispose();
      }
      context.onProgress((index + 1) / items.length);
    }
    return StoryExportResult(outputs);
  }
}

/// One audio element to mix into an exported video.
final class StoryExportAudio {
  /// Creates an audio track description.
  const StoryExportAudio({
    required this.source,
    required this.start,
    required this.duration,
    required this.trimStart,
    required this.volume,
  });

  /// The audio source (asset references resolved).
  final StorySource source;

  /// When the track starts in the video.
  final Duration start;

  /// How long it plays.
  final Duration duration;

  /// Offset into the audio.
  final Duration trimStart;

  /// Volume between 0 and 1.
  final double volume;
}

/// Encodes rendered frames into a video file.
///
/// story_framework has no encoder dependency: implement this with the
/// platform encoder or package of your choice (for example ffmpeg).
abstract interface class StoryVideoEncoder {
  /// Starts a video of [width]×[height] at [frameRate].
  Future<void> begin({
    required int width,
    required int height,
    required int frameRate,
  });

  /// Adds one RGBA frame repeated [count] times (identical frames are passed
  /// once with a count, so encoders can avoid redundant work).
  Future<void> addFrame(ByteData rgba, {int count = 1});

  /// Finishes the file, mixing [audio], and returns its bytes.
  Future<StoryExportOutput> finish(List<StoryExportAudio> audio);

  /// Discards a partial video after cancellation or failure.
  Future<void> abort();
}

/// Exports a slideshow-style video: each item's rendered frame held for its
/// duration, with its audio passed to the encoder.
///
/// Video elements appear as their poster frame: decoding source video frame
/// by frame requires a platform media pipeline, which an encoder can supply
/// by overriding this exporter.
final class StoryVideoExporter implements StoryExporter {
  /// Creates the exporter around [encoder].
  StoryVideoExporter(
    this.encoder, {
    StoryItemSnapshotter? snapshotter,
    this.defaultItemDuration = const Duration(seconds: 5),
  }) : snapshotter = snapshotter ?? StoryItemSnapshotter();

  /// Encodes the frames.
  final StoryVideoEncoder encoder;

  /// Renders items.
  final StoryItemSnapshotter snapshotter;

  /// Duration of items without a fixed duration.
  final Duration defaultItemDuration;

  @override
  String get id => 'video';

  @override
  bool supports(StoryExportConfig config) =>
      config.format == StoryExportFormat.video;

  Duration _durationOf(StoryItem item) => switch (item.duration) {
        FixedItemDuration(:final duration) => duration,
        MediaItemDuration(:final maxDuration, :final fallback) =>
          fallback ?? maxDuration ?? defaultItemDuration,
        _ => defaultItemDuration,
      };

  @override
  Future<StoryExportResult> export(StoryExportContext context) async {
    final items = context.items;
    final rate = context.config.frameRate;
    final audio = <StoryExportAudio>[];
    var elapsed = Duration.zero;
    await encoder.begin(
        width: context.width, height: context.height, frameRate: rate);
    try {
      for (final (index, item) in items.indexed) {
        context.checkCancelled();
        final duration = _durationOf(item);
        final image = await snapshotter.capture(context.document, item,
            width: context.width);
        try {
          final rgba = await image.toByteData();
          if (rgba == null) throw const ExportException('Frame capture failed');
          final frames = (duration.inMicroseconds * rate / 1000000).round();
          await encoder.addFrame(rgba, count: frames < 1 ? 1 : frames);
        } finally {
          image.dispose();
        }
        if (context.config.includeAudio) {
          for (final element in item.elements) {
            if (element is AudioElement && element.visible && !element.muted) {
              audio.add(StoryExportAudio(
                source: context.document.resolveSource(element.source),
                start: elapsed,
                duration: duration,
                trimStart: element.trimStart,
                volume: element.volume,
              ));
            }
          }
        }
        elapsed += duration;
        context.onProgress((index + 1) / (items.length + 1));
      }
      context.checkCancelled();
      return StoryExportResult([await encoder.finish(audio)]);
    } catch (_) {
      await encoder.abort();
      rethrow;
    }
  }
}
