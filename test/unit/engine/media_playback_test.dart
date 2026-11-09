import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/engine.dart';

import '../../helpers/engine_fakes.dart';

const ms = Duration(milliseconds: 1);
const s = Duration(seconds: 1);

StoryTransform get _box =>
    const StoryTransform(position: StoryPoint(0, 0), size: StorySize(100, 100));

StoryItem videoItem(
  String id, {
  Duration trimStart = Duration.zero,
  Duration? trimEnd,
  Duration? maxDuration,
  Duration? fallback,
  bool loop = false,
  bool muted = false,
  StorySource source = const FileStorySource('/clip.mp4'),
}) =>
    StoryItem(
      id: id,
      duration: MediaItemDuration(
        elementId: '$id-video',
        maxDuration: maxDuration,
        fallback: fallback,
      ),
      elements: [
        VideoElement(
          id: '$id-video',
          transform: _box,
          source: source,
          trimStart: trimStart,
          trimEnd: trimEnd,
          loop: loop,
          muted: muted,
          volume: 0.5,
        ),
      ],
    );

void main() {
  late EngineHarness harness;
  late FakeMediaFactory media;
  final controllers = <StoryController>[];

  setUp(() {
    harness = EngineHarness();
    media = FakeMediaFactory();
  });

  tearDown(() async {
    for (final controller in controllers) {
      await controller.dispose();
    }
    controllers.clear();
  });

  StoryController create(
    List<StoryItem> items, {
    List<StoryAsset> assets = const [],
    StoryPlaybackConfig config = const StoryPlaybackConfig(),
    bool withFactory = true,
  }) {
    final controller = StoryController(
      document: StoryDocument(
        id: 'doc',
        assets: assets,
        groups: [StoryGroup(id: 'g', items: items)],
      ),
      config: config,
      clock: harness.clock,
      tickerFactory: harness.createTicker,
      mediaFactories: withFactory ? [media] : const [],
    );
    controllers.add(controller);
    return controller;
  }

  StoryPlaybackState stateOf(StoryController c) => c.state.value;

  test('item duration comes from the media, minus trims, capped', () async {
    final c = create([
      videoItem('a', trimStart: s * 2),
      videoItem('b', trimStart: s, trimEnd: s * 4),
      videoItem('c', maxDuration: s * 3),
      videoItem('d', trimEnd: s * 60),
    ]);
    final durations = <Duration?>[];
    for (var i = 0; i < 4; i++) {
      if (i == 0) {
        c.play();
      } else {
        c.next();
      }
      await flush();
      durations.add(stateOf(c).duration);
    }
    expect(durations, [s * 8, s * 3, s * 3, s * 10]);
  });

  test('initializes, configures, and plays the driving media', () async {
    final c = create([videoItem('a', trimStart: s * 2)]);
    c.play();
    await flush();
    final controller = media.last;
    expect(controller.calls, [
      'initialize',
      'speed:1.0',
      'volume:0.5',
      'seek:0:00:02.000000',
      'play',
    ]);
    expect(c.currentMedia, same(controller));
    expect(stateOf(c).status, StoryPlaybackStatus.playing);
  });

  test('resolves asset references before creating media', () async {
    final c = create(
      [videoItem('a', source: const ReferenceStorySource('clip'))],
      assets: [
        StoryAsset(
          id: 'clip',
          type: StoryAssetType.video,
          source: const FileStorySource('/real.mp4'),
        ),
      ],
    );
    c.play();
    await flush();
    expect(media.last.source, const FileStorySource('/real.mp4'));
  });

  test('muted elements get zero volume', () async {
    final c = create([videoItem('a', muted: true)]);
    c.play();
    await flush();
    expect(media.last.calls, contains('volume:0.0'));
  });

  test('media pauses, resumes, seeks, and changes speed with the timeline',
      () async {
    final c = create([videoItem('a')]);
    c.play();
    await flush();
    final controller = media.last..calls.clear();

    c.pause();
    c.play();
    c.seekTo(s * 3);
    c.setPlaybackSpeed(1.5);
    await flush();
    expect(controller.calls,
        ['pause', 'play', 'seek:0:00:03.000000', 'speed:1.5']);
  });

  test('the timeline follows reported media positions', () async {
    final c = create([videoItem('a', trimStart: s)]);
    c.play();
    await flush();
    harness.advance(s * 2);
    // The player fell behind (for example after a stall).
    media.last.emit(const StoryMediaSnapshot(
      status: StoryMediaStatus.playing,
      position: Duration(milliseconds: 2500), // 1.5 s into the trimmed clip
    ));
    expect(stateOf(c).position, ms * 1500);
    harness.advance(ms * 500);
    expect(stateOf(c).position, s * 2);
  });

  test('buffering holds the timeline but keeps the media playing', () async {
    final c = create([videoItem('a')]);
    c.play();
    await flush();
    final controller = media.last..calls.clear();

    controller.emit(const StoryMediaSnapshot(
        status: StoryMediaStatus.buffering, position: Duration(seconds: 1)));
    expect(stateOf(c).bufferingStatus, StoryBufferingStatus.buffering);
    expect(stateOf(c).pauseReasons, {StoryPauseReason.buffering});
    expect(stateOf(c).status, StoryPlaybackStatus.paused);
    harness.clock.advance(s * 5);
    expect(c.position, s);
    expect(controller.calls, isEmpty, reason: 'media is not paused');

    controller.emit(const StoryMediaSnapshot(
        status: StoryMediaStatus.playing, position: Duration(seconds: 1)));
    expect(stateOf(c).status, StoryPlaybackStatus.playing);
    expect(stateOf(c).bufferingStatus, StoryBufferingStatus.ready);
  });

  test('user pause during buffering pauses the media', () async {
    final c = create([videoItem('a')]);
    c.play();
    await flush();
    final controller = media.last;
    controller
        .emit(const StoryMediaSnapshot(status: StoryMediaStatus.buffering));
    controller.calls.clear();
    c.pause();
    await flush();
    expect(controller.calls, ['pause']);
  });

  test('media completion advances to the next item', () async {
    final c = create([videoItem('a'), videoItem('b')]);
    c.play();
    await flush();
    final first = media.last;
    first.emit(const StoryMediaSnapshot(
        status: StoryMediaStatus.completed, position: Duration(seconds: 10)));
    await flush();
    expect(c.currentItem?.id, 'b');
    expect(first.disposed, isTrue);
    expect(media.created, hasLength(2));
  });

  test('looping drivers end after one media length on the clock', () async {
    final c = create([videoItem('a', loop: true), videoItem('b')]);
    c.play();
    await flush();
    harness.advance(s * 6);
    // The looping player wraps around; the timeline must not follow it.
    media.last.emit(const StoryMediaSnapshot(
        status: StoryMediaStatus.playing, position: Duration(seconds: 1)));
    harness.advance(s * 4);
    await flush();
    expect(c.currentItem?.id, 'b');
  });

  test('media errors use the error policy', () async {
    final c = create([videoItem('a')]);
    c.play();
    await flush();
    media.last.emit(const StoryMediaSnapshot(
      status: StoryMediaStatus.error,
      error: MediaInitializationException('decoder failed'),
    ));
    expect(stateOf(c).status, StoryPlaybackStatus.error);
    expect(stateOf(c).error?.message, 'decoder failed');
    expect(media.last.disposed, isTrue);
    expect(c.currentMedia, isNull);
  });

  test('initialization failures are reported', () async {
    media.onCreate = (controller) =>
        controller.initialization = Completer<void>()
          ..completeError(const MediaInitializationException('404'));
    final c = create([videoItem('a')]);
    c.play();
    await flush();
    expect(stateOf(c).error, isA<MediaInitializationException>());
    expect(media.last.disposed, isTrue);
  });

  test('navigating during initialization disposes the stale media', () async {
    final hanging = Completer<void>();
    media.onCreate = (controller) {
      if (media.created.isEmpty) controller.initialization = hanging;
    };
    final c = create([videoItem('a'), videoItem('b')]);
    c.play();
    await flush();
    final stale = media.last;
    c.next();
    await flush();
    expect(stale.disposed, isTrue);

    hanging.complete();
    await flush();
    expect(c.currentItem?.id, 'b');
    expect(stateOf(c).status, StoryPlaybackStatus.playing);
    expect(stale.calls, isNot(contains('play')));
    expect(c.currentMedia, same(media.last));
  });

  test('stale snapshots from replaced media are ignored', () async {
    final c = create([videoItem('a'), videoItem('b')]);
    c.play();
    await flush();
    final first = media.last;
    c.next();
    await flush();
    first.emit(const StoryMediaSnapshot(status: StoryMediaStatus.completed));
    await flush();
    expect(c.currentItem?.id, 'b');
  });

  test('without a factory, the fallback duration is used', () async {
    final c = create([videoItem('a', fallback: s * 4)], withFactory: false);
    c.play();
    await flush();
    expect(stateOf(c).duration, s * 4);
    expect(stateOf(c).status, StoryPlaybackStatus.playing);
  });

  test('without a factory or fallback, the item fails', () async {
    final c = create([videoItem('a')], withFactory: false);
    c.play();
    await flush();
    expect(stateOf(c).error, isA<UnsupportedElementException>());
  });

  test('a media duration needs a time-based element', () async {
    final c = create([
      StoryItem(id: 'a', duration: const MediaItemDuration()),
    ]);
    c.play();
    await flush();
    expect(stateOf(c).error, isA<PlaybackException>());
  });

  test('dispose waits for media disposal', () async {
    final c = create([videoItem('a')]);
    c.play();
    await flush();
    final controller = media.last;
    await c.dispose();
    expect(controller.disposed, isTrue);
  });
}
