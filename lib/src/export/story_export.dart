import 'dart:async';

import 'package:flutter/foundation.dart';

import '../composition/document/story_document.dart';
import '../composition/items/story_item.dart';
import '../composition/validation/story_document_validator.dart';
import '../core/errors/story_exceptions.dart';
import '../media/cache/story_resource_loader.dart';

/// What an export produces.
enum StoryExportFormat {
  /// The serialized document (JSON).
  document,

  /// One PNG image per item.
  png,

  /// A video, through an app-supplied encoder.
  video,
}

/// Export settings.
@immutable
final class StoryExportConfig {
  /// Creates export settings.
  const StoryExportConfig({
    required this.format,
    this.width,
    this.itemIds,
    this.frameRate = 30,
    this.includeAudio = true,
    this.validate = true,
  });

  /// The output format.
  final StoryExportFormat format;

  /// Output width in pixels; height follows the canvas aspect ratio.
  /// `null` uses the canvas width.
  final int? width;

  /// Items to export, or `null` for every item in playback order.
  final List<String>? itemIds;

  /// Frames per second for video.
  final int frameRate;

  /// Whether video exports pass audio elements to the encoder.
  final bool includeAudio;

  /// Whether to validate the document first and fail on errors.
  final bool validate;

  /// Throws a [ConfigurationException] if any value is invalid.
  void check() {
    final w = width;
    if (w != null && w <= 0) {
      throw const ConfigurationException('Export width must be positive');
    }
    if (frameRate <= 0 || frameRate > 120) {
      throw const ConfigurationException('frameRate must be 1–120');
    }
  }
}

/// One produced file.
@immutable
final class StoryExportOutput {
  /// Creates an output.
  const StoryExportOutput({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  /// Suggested file name, such as `item-1.png`.
  final String name;

  /// MIME type.
  final String mimeType;

  /// The file content.
  final Uint8List bytes;
}

/// The outcome of an export.
@immutable
final class StoryExportResult {
  /// Creates a result.
  StoryExportResult(List<StoryExportOutput> outputs)
      : outputs = List.unmodifiable(outputs);

  /// Produced files. Writing them anywhere is the app's decision.
  final List<StoryExportOutput> outputs;
}

/// Shared state of one running export.
final class StoryExportContext {
  /// Creates a context.
  StoryExportContext({
    required this.document,
    required this.config,
    required this.token,
    required this.onProgress,
  });

  /// The document being exported.
  final StoryDocument document;

  /// The settings.
  final StoryExportConfig config;

  /// Cancelled when the job is cancelled.
  final StoryCancellationToken token;

  /// Reports progress between 0 and 1.
  final ValueChanged<double> onProgress;

  /// The items selected by [StoryExportConfig.itemIds], in order.
  List<StoryItem> get items {
    final ids = config.itemIds;
    final all = document.allItems.toList();
    if (ids == null) return all;
    return [
      for (final item in all)
        if (ids.contains(item.id)) item
    ];
  }

  /// Output pixel width.
  int get width => config.width ?? document.canvas.width.round();

  /// Output pixel height, keeping the canvas aspect ratio.
  int get height => (width / document.canvas.aspectRatio).round();

  /// Throws a [StoryCancelledException] if the job was cancelled.
  void checkCancelled() {
    if (token.isCancelled) throw const StoryCancelledException();
  }
}

/// Produces export output for some formats.
///
/// Register custom exporters (for example GIF or WebP) with
/// [StoryExporterRegistry].
abstract interface class StoryExporter {
  /// Unique id.
  String get id;

  /// Whether this exporter handles [config].
  bool supports(StoryExportConfig config);

  /// Runs the export. Must call `context.checkCancelled()` regularly and
  /// release temporary resources even when cancelled or failing.
  Future<StoryExportResult> export(StoryExportContext context);
}

/// A running export with progress and cancellation.
final class StoryExportJob {
  StoryExportJob._(this.result, this._progress, this._token);

  /// Completes with the outputs, or an [ExportException] /
  /// [StoryCancelledException].
  final Future<StoryExportResult> result;

  final ValueNotifier<double> _progress;
  final StoryCancellationToken _token;

  /// Progress between 0 and 1.
  ValueListenable<double> get progress => _progress;

  /// Whether [cancel] was called.
  bool get isCancelled => _token.isCancelled;

  /// Stops the export as soon as possible.
  void cancel() => _token.cancel();
}

/// The exporters available to an app.
final class StoryExporterRegistry {
  /// Creates a registry with [exporters]; later ones win for a format.
  StoryExporterRegistry(Iterable<StoryExporter> exporters)
      : _exporters = List.of(exporters);

  final List<StoryExporter> _exporters;

  /// Registered exporters.
  List<StoryExporter> get exporters => List.unmodifiable(_exporters);

  /// Adds [exporter]; throws a [ConfigurationException] on a duplicate id.
  void register(StoryExporter exporter) {
    if (_exporters.any((e) => e.id == exporter.id)) {
      throw ConfigurationException('Exporter "${exporter.id}" already exists');
    }
    _exporters.add(exporter);
  }

  /// Starts exporting [document] with [config].
  ///
  /// Validation and unsupported formats fail the job's `result` with an
  /// [ExportException].
  StoryExportJob export(
    StoryDocument document,
    StoryExportConfig config, {
    StoryDocumentValidator validator = const StoryDocumentValidator(),
  }) {
    final token = StoryCancellationToken();
    final progress = ValueNotifier<double>(0);
    final result = _run(document, config, validator, token, progress);
    return StoryExportJob._(result, progress, token);
  }

  Future<StoryExportResult> _run(
    StoryDocument document,
    StoryExportConfig config,
    StoryDocumentValidator validator,
    StoryCancellationToken token,
    ValueNotifier<double> progress,
  ) async {
    try {
      config.check();
      if (config.validate) {
        final validation = validator.validate(document);
        if (!validation.isValid) {
          throw ExportException('The story is invalid',
              cause: InvalidCompositionException(validation.issues));
        }
      }
      StoryExporter? exporter;
      for (final candidate in _exporters.reversed) {
        if (candidate.supports(config)) {
          exporter = candidate;
          break;
        }
      }
      if (exporter == null) {
        throw ExportException('No exporter for ${config.format.name}');
      }
      final result = await exporter.export(StoryExportContext(
        document: document,
        config: config,
        token: token,
        onProgress: (value) => progress.value = value.clamp(0.0, 1.0),
      ));
      progress.value = 1;
      return result;
    } on StoryCancelledException {
      rethrow;
    } on ExportException {
      rethrow;
    } catch (error) {
      throw ExportException('Export failed', cause: error);
    }
  }
}
