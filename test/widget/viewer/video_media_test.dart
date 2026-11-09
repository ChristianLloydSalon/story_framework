import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/viewer.dart';

import '../../helpers/engine_fakes.dart';

final transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

const _box =
    StoryTransform(position: StoryPoint(540, 960), size: StorySize(1080, 1920));

StoryItem videoItem(String id, {StorySource? poster}) => StoryItem(
      id: id,
      duration: MediaItemDuration(elementId: '$id-video'),
      elements: [
        VideoElement(
          id: '$id-video',
          transform: _box,
          source: const FileStorySource('/clip.mp4'),
          poster: poster,
        ),
      ],
    );

class _Host extends StatelessWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      );
}

void main() {
  final harness = EngineHarness();
  final controllers = <StoryController>[];
  setUp(harness.reset);
  tearDown(() async {
    for (final c in controllers) {
      await c.dispose();
    }
    controllers.clear();
  });

  testWidgets('the viewer shows frames of the engine-driven controller',
      (tester) async {
    final media = FakeMediaFactory(visual: true);
    final controller = StoryController(
      document: StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [videoItem('a'), videoItem('b')]),
      ]),
      clock: harness.clock,
      tickerFactory: harness.createTicker,
      mediaFactories: [media],
    );
    controllers.add(controller);
    await tester.pumpWidget(
        _Host(child: StoryViewer.controller(controller: controller)));
    await tester.pump();
    await tester.pump();

    expect(find.text('video frames'), findsOneWidget);
    final playing = controller.currentMedia as FakeVisualMedia;
    expect(controller.mediaFor('a-video'), same(playing));
    expect(media.created, hasLength(2), reason: 'next video preloaded');

    // Becoming "playing" is a status change; position updates afterwards
    // must not rebuild the video view.
    playing.emit(const StoryMediaSnapshot(
      status: StoryMediaStatus.playing,
      duration: Duration(seconds: 10),
    ));
    await tester.pump();
    final builds = playing.viewBuilds;
    for (var i = 0; i < 5; i++) {
      playing.emit(StoryMediaSnapshot(
        status: StoryMediaStatus.playing,
        position: Duration(milliseconds: 200 * i),
        duration: const Duration(seconds: 10),
      ));
      await tester.pump();
    }
    expect(playing.viewBuilds, builds);
  });

  testWidgets('without a playback engine, posters are shown', (tester) async {
    final document = StoryDocument(id: 'd', groups: [
      StoryGroup(id: 'g', items: [
        videoItem('a', poster: MemoryStorySource(transparentPng)),
        videoItem('b'),
      ]),
    ]);
    await tester.pumpWidget(_Host(
      child: Row(children: [
        Expanded(
          child: StoryItemView(
              document: document, item: document.groups.single.items[0]),
        ),
        Expanded(
          child: StoryItemView(
              document: document, item: document.groups.single.items[1]),
        ),
      ]),
    ));
    expect(find.byType(Image), findsOneWidget, reason: 'poster');
    expect(find.text('▶'), findsOneWidget, reason: 'placeholder');
  });

  testWidgets('preview factories give editor-style views a first frame',
      (tester) async {
    final previews = FakeMediaFactory(visual: true);
    final document = StoryDocument(id: 'd', groups: [
      StoryGroup(id: 'g', items: [videoItem('a')]),
    ]);
    await tester.pumpWidget(_Host(
      child: StoryItemView(
        document: document,
        item: document.groups.single.items.single,
        mode: StoryRenderMode.editor,
        options: StoryRenderOptions(previewMediaFactories: [previews]),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('video frames'), findsOneWidget);
    final preview = previews.created.single;
    expect(preview.calls,
        containsAllInOrder(['initialize', 'volume:0.0', 'pause']));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(preview.disposed, isTrue, reason: 'previews are owned by the view');
  });

  testWidgets('media errors show the error state', (tester) async {
    final media = FakeMediaFactory(visual: true);
    final controller = StoryController(
      document: StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [videoItem('a')]),
      ]),
      clock: harness.clock,
      tickerFactory: harness.createTicker,
      mediaFactories: [media],
      config: const StoryPlaybackConfig(mediaPreload: StoryMediaPreload.none),
    );
    controllers.add(controller);
    await tester.pumpWidget(_Host(
      child: StoryViewer.controller(
        controller: controller,
        renderOptions: StoryRenderOptions(
          onError: (_, __, ___) {},
          errorBuilder: (context, element, error) => const Text('broken'),
        ),
        errorBuilder: (context, c, error) => const SizedBox.shrink(),
      ),
    ));
    await tester.pump();
    await tester.pump();
    final playing = controller.currentMedia as FakeVisualMedia;
    playing.emit(const StoryMediaSnapshot(
      status: StoryMediaStatus.error,
      error: MediaInitializationException('decode failed'),
    ));
    await tester.pump();
    expect(controller.state.value.status, StoryPlaybackStatus.error);
  });

  test('prefetch collects every image source of an item', () {
    final item = StoryItem(
      id: 'i',
      background: const StoryMediaBackground(FileStorySource('/bg.png')),
      elements: [
        ImageElement(
            id: 'img',
            transform: _box,
            source: const FileStorySource('/a.png')),
        StickerElement(
          id: 's',
          transform: _box,
          sticker: const ImageSticker(FileStorySource('/s.png')),
        ),
        VideoElement(
          id: 'v',
          transform: _box,
          source: const FileStorySource('/v.mp4'),
          poster: const FileStorySource('/p.png'),
        ),
        ImageElement(
          id: 'hidden',
          transform: _box,
          source: const FileStorySource('/h.png'),
          visible: false,
        ),
      ],
    );
    expect(
      StoryImagePrefetcher.imageSourcesOf(item),
      const [
        FileStorySource('/bg.png'),
        FileStorySource('/a.png'),
        FileStorySource('/s.png'),
        FileStorySource('/p.png'),
      ],
    );
  });
}
