import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/export.dart';

StoryDocument exportDoc() => StoryDocument(
      id: 'trip',
      canvas: const StoryCanvasConfiguration(width: 108, height: 192),
      groups: [
        StoryGroup(id: 'g', items: [
          StoryItem(
            id: 'one',
            duration: const FixedItemDuration(Duration(seconds: 2)),
            background: const StoryColorBackground(StoryColor(0xFFFF0000)),
            elements: [
              ShapeElement(
                id: 'dot',
                transform: const StoryTransform(
                    position: StoryPoint(54, 96), size: StorySize(20, 20)),
                shape: StoryShapeType.ellipse,
                fillColor: StoryColor.white,
              ),
              AudioElement(
                  id: 'music',
                  source: const FileStorySource('/a.mp3'),
                  volume: 0.5),
            ],
          ),
          StoryItem(
            id: 'two',
            duration: const FixedItemDuration(Duration(seconds: 1)),
            background: const StoryColorBackground(StoryColor(0xFF0000FF)),
          ),
        ]),
      ],
    );

final class _FakeEncoder implements StoryVideoEncoder {
  final List<int> frameCounts = [];
  List<StoryExportAudio> audio = const [];
  bool aborted = false;
  (int, int, int)? started;

  @override
  Future<void> begin(
          {required int width,
          required int height,
          required int frameRate}) async =>
      started = (width, height, frameRate);

  @override
  Future<void> addFrame(ByteData rgba, {int count = 1}) async =>
      frameCounts.add(count);

  @override
  Future<StoryExportOutput> finish(List<StoryExportAudio> audio) async {
    this.audio = audio;
    return StoryExportOutput(
        name: 'story.mp4', mimeType: 'video/mp4', bytes: Uint8List(1));
  }

  @override
  Future<void> abort() async => aborted = true;
}

void main() {
  test('documents export as JSON that decodes back', () async {
    final registry = StoryExporterRegistry([const StoryDocumentExporter()]);
    final job = registry.export(exportDoc(),
        const StoryExportConfig(format: StoryExportFormat.document));
    final result = await job.result;
    final text = utf8.decode(result.outputs.single.bytes);
    expect(const StoryDocumentCodec().decodeFromString(text), exportDoc());
    expect(job.progress.value, 1);
  });

  test('invalid stories and missing exporters fail clearly', () async {
    final registry = StoryExporterRegistry([const StoryDocumentExporter()]);
    await expectLater(
      registry
          .export(StoryDocument(id: ''),
              const StoryExportConfig(format: StoryExportFormat.document))
          .result,
      throwsA(isA<ExportException>()),
    );
    await expectLater(
      registry
          .export(exportDoc(),
              const StoryExportConfig(format: StoryExportFormat.png))
          .result,
      throwsA(isA<ExportException>()),
    );
    await expectLater(
      registry
          .export(
              exportDoc(),
              const StoryExportConfig(
                  format: StoryExportFormat.document, frameRate: 0))
          .result,
      throwsA(isA<ExportException>()),
    );
  });

  testWidgets('items render to PNGs with the real pixels', (tester) async {
    final registry = StoryExporterRegistry([StoryPngExporter()]);
    final result = await tester.runAsync(() => registry
        .export(exportDoc(),
            const StoryExportConfig(format: StoryExportFormat.png, width: 54))
        .result);
    final outputs = result?.outputs ?? const [];
    expect(outputs.map((o) => o.name), ['one.png', 'two.png']);
    final png = outputs.first.bytes;
    expect(png.sublist(1, 4), utf8.encode('PNG'));

    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });
    expect(image?.width, 54);
    expect(image?.height, 96);
    final pixels = await tester.runAsync(() async => image?.toByteData());
    // Top-left pixel is the red background.
    expect(pixels?.getUint8(0), 255);
    expect(pixels?.getUint8(2), 0);
    image?.dispose();
  });

  testWidgets('video export holds frames per duration and passes audio',
      (tester) async {
    final encoder = _FakeEncoder();
    final registry = StoryExporterRegistry([StoryVideoExporter(encoder)]);
    final progress = <double>[];
    // Export work must start in real time, not in the test's fake time.
    final result = await tester.runAsync(() {
      final job = registry.export(
          exportDoc(),
          const StoryExportConfig(
              format: StoryExportFormat.video, frameRate: 10));
      job.progress.addListener(() => progress.add(job.progress.value));
      return job.result;
    });
    expect(result?.outputs.single.name, 'story.mp4');
    expect(encoder.started, (108, 192, 10));
    expect(encoder.frameCounts, [20, 10]);
    expect(encoder.audio.single.volume, 0.5);
    expect(encoder.audio.single.start, Duration.zero);
    expect(progress.last, 1);
  });

  testWidgets('cancelling a video export aborts the encoder', (tester) async {
    final encoder = _FakeEncoder();
    final registry = StoryExporterRegistry([StoryVideoExporter(encoder)]);
    final cancelled = await tester.runAsync(() async {
      final job = registry.export(exportDoc(),
          const StoryExportConfig(format: StoryExportFormat.video));
      job.cancel();
      await expectLater(job.result, throwsA(isA<StoryCancelledException>()));
      return job.isCancelled;
    });
    expect(encoder.aborted, isTrue);
    expect(cancelled, isTrue);
  });
}
