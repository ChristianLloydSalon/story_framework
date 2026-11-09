import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/engine.dart';

import '../../helpers/engine_fakes.dart';

const ms = Duration(milliseconds: 1);
const s = Duration(seconds: 1);

StoryItem fixed(String id, [Duration duration = const Duration(seconds: 5)]) =>
    StoryItem(id: id, duration: FixedItemDuration(duration));

StoryDocument doc(List<List<StoryItem>> groups) => StoryDocument(
      id: 'doc',
      groups: [
        for (final (i, items) in groups.indexed)
          StoryGroup(id: 'g$i', items: items),
      ],
    );

StoryItemLocation at(int group, int item) =>
    StoryItemLocation(groupIndex: group, itemIndex: item);

void main() {
  late EngineHarness harness;
  late List<StoryPlaybackEvent> events;
  final controllers = <StoryController>[];

  setUp(() {
    harness = EngineHarness();
    events = [];
  });

  tearDown(() async {
    for (final controller in controllers) {
      await controller.dispose();
    }
    controllers.clear();
  });

  StoryController create(
    StoryDocument document, {
    StoryPlaybackConfig config = const StoryPlaybackConfig(),
    List<StoryMediaControllerFactory> mediaFactories = const [],
    Map<String, StoryDurationProvider> durationProviders = const {},
    StoryItemLocation? initialLocation,
  }) {
    final controller = StoryController(
      document: document,
      config: config,
      clock: harness.clock,
      tickerFactory: harness.createTicker,
      mediaFactories: mediaFactories,
      durationProviders: durationProviders,
      initialLocation: initialLocation,
    );
    controller.events.listen(events.add);
    controllers.add(controller);
    return controller;
  }

  StoryPlaybackState stateOf(StoryController c) => c.state.value;

  group('starting', () {
    test('is idle until play, then loads and plays', () async {
      final c = create(doc([
        [fixed('a')],
      ]));
      expect(stateOf(c).status, StoryPlaybackStatus.idle);
      expect(harness.ticker!.isActive, isFalse);

      final statuses = <StoryPlaybackStatus>[];
      c.state.addListener(() => statuses.add(stateOf(c).status));
      c.play();
      await flush();
      expect(
          statuses, [StoryPlaybackStatus.loading, StoryPlaybackStatus.playing]);
      expect(stateOf(c).duration, s * 5);
      expect(harness.ticker!.isActive, isTrue);
      expect(events, [StoryItemStartedEvent(at(0, 0))]);
    });

    test('stays loading while the duration is being resolved', () async {
      final pending = Completer<Duration?>();
      final c = create(
        doc([
          [StoryItem(id: 'a', duration: CustomItemDuration('slow'))],
        ]),
        durationProviders: {'slow': _Provider((_) => pending.future)},
      );
      c.play();
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.loading);
      expect(harness.ticker!.isActive, isFalse);
      pending.complete(s);
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
    });

    test('uses the configured default duration for untimed items', () async {
      final c = create(
        doc([
          [StoryItem(id: 'a')],
        ]),
        config: const StoryPlaybackConfig(
            defaultItemDuration: Duration(seconds: 3)),
      );
      c.play();
      await flush();
      expect(stateOf(c).duration, s * 3);
    });

    test('an empty document completes immediately', () async {
      final c = create(StoryDocument(id: 'empty'));
      expect(c.location, isNull);
      c.play();
      expect(stateOf(c).status, StoryPlaybackStatus.completed);
      await flush();
      expect(events, [const StoryPlaybackCompletedEvent()]);
    });

    test('rejects invalid configuration and locations', () {
      expect(
        () => create(doc([]),
            config: const StoryPlaybackConfig(initialPlaybackSpeed: 0)),
        throwsA(isA<ConfigurationException>()),
      );
      expect(
        () => create(
            doc([
              [fixed('a')],
            ]),
            initialLocation: at(0, 3)),
        throwsArgumentError,
      );
    });

    test('starts at the initial location', () async {
      final c = create(
        doc([
          [fixed('a'), fixed('b')],
        ]),
        initialLocation: at(0, 1),
      );
      c.play();
      await flush();
      expect(c.currentItem?.id, 'b');
    });
  });

  group('timeline', () {
    test('position follows the clock, not the tick count', () async {
      final c = create(doc([
        [fixed('a', const Duration(seconds: 60))],
      ]));
      c.play();
      await flush();

      // 30 s of irregular ticks, including a long stall.
      harness.run(s * 10, step: ms * 16);
      harness.run(s * 10, step: ms * 33);
      harness.advance(s * 10);
      expect(stateOf(c).position, s * 30);
      expect(stateOf(c).progress, 0.5);
    });

    test('live position is readable between ticks', () async {
      final c = create(doc([
        [fixed('a')],
      ]));
      c.play();
      await flush();
      harness.clock.advance(ms * 1200);
      expect(c.position, ms * 1200);
    });

    test('playback speed scales the timeline from the moment it changes',
        () async {
      final c = create(doc([
        [fixed('a', const Duration(seconds: 20))],
      ]));
      c.play();
      await flush();
      harness.advance(s * 2);
      c.setPlaybackSpeed(2);
      harness.advance(s * 2);
      expect(stateOf(c).position, s * 6);
      expect(stateOf(c).playbackSpeed, 2);
      expect(() => c.setPlaybackSpeed(-1), throwsArgumentError);
    });

    test('seeks are clamped to the item', () async {
      final c = create(doc([
        [fixed('a', const Duration(seconds: 10))],
      ]));
      c.play();
      await flush();
      c.seekTo(s * 4);
      expect(stateOf(c).position, s * 4);
      harness.advance(s * 1);
      expect(stateOf(c).position, s * 5);
      c.seekTo(-s);
      expect(stateOf(c).position, Duration.zero);
    });

    test('seeking while idle sets the start position', () async {
      final c = create(doc([
        [fixed('a', const Duration(seconds: 10))],
      ]));
      c.seekTo(s * 3);
      c.play();
      await flush();
      expect(stateOf(c).position, s * 3);
    });
  });

  group('pause reasons', () {
    test('playback resumes only when every reason is cleared', () async {
      final c = create(doc([
        [fixed('a', const Duration(seconds: 10))],
      ]));
      c.play();
      await flush();
      harness.advance(s * 1);

      c.pause();
      c.addPauseReason(StoryPauseReason.modal);
      expect(stateOf(c).status, StoryPlaybackStatus.paused);
      expect(harness.ticker!.isActive, isFalse);
      harness.clock.advance(s * 5);

      c.play(); // clears only the user reason
      expect(stateOf(c).status, StoryPlaybackStatus.paused);
      expect(stateOf(c).pauseReasons, {StoryPauseReason.modal});

      c.removePauseReason(StoryPauseReason.modal);
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
      harness.advance(s * 1);
      expect(stateOf(c).position, s * 2, reason: 'paused time is not counted');
    });

    test('reasons added while loading hold playback once ready', () async {
      final c = create(doc([
        [fixed('a')],
      ]));
      c.play();
      c.addPauseReason(StoryPauseReason.navigationOverlay);
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.paused);
    });

    test('pausing before play is kept until play is called', () async {
      final c = create(doc([
        [fixed('a')],
      ]));
      c.addPauseReason(StoryPauseReason.external);
      c.play();
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.paused);
    });
  });

  group('advancing', () {
    test('advances through items and groups, then completes', () async {
      final c = create(doc([
        [fixed('a', s), fixed('b', s)],
        [fixed('c', s)],
      ]));
      c.play();
      await flush();
      harness.advance(s);
      await flush();
      expect(c.currentItem?.id, 'b');
      harness.advance(s);
      await flush();
      expect(c.currentItem?.id, 'c');
      harness.advance(s);
      await flush();

      expect(stateOf(c).status, StoryPlaybackStatus.completed);
      expect(harness.ticker!.isActive, isFalse);
      expect(events, [
        StoryItemStartedEvent(at(0, 0)),
        StoryItemCompletedEvent(at(0, 0)),
        StoryItemStartedEvent(at(0, 1)),
        StoryItemCompletedEvent(at(0, 1)),
        const StoryGroupCompletedEvent(0),
        StoryItemStartedEvent(at(1, 0)),
        StoryItemCompletedEvent(at(1, 0)),
        const StoryGroupCompletedEvent(1),
        const StoryPlaybackCompletedEvent(),
      ]);
    });

    test('new items start from zero', () async {
      final c = create(doc([
        [fixed('a', s), fixed('b', s * 10)],
      ]));
      c.play();
      await flush();
      harness.advance(ms * 1500); // overshoots item a
      await flush();
      expect(c.currentItem?.id, 'b');
      expect(stateOf(c).position, Duration.zero);
    });

    test('empty groups are skipped', () async {
      final c = create(doc([
        [fixed('a', s)],
        [],
        [fixed('c', s)],
      ]));
      c.play();
      await flush();
      harness.advance(s);
      await flush();
      expect(c.location, at(2, 0));
    });

    test('without auto-advance, holds at the end of the item', () async {
      final c = create(
        doc([
          [fixed('a', s), fixed('b', s)],
        ]),
        config: const StoryPlaybackConfig(autoAdvance: false),
      );
      c.play();
      await flush();
      harness.advance(s * 2);
      await flush();
      expect(c.currentItem?.id, 'a');
      expect(stateOf(c).position, s);
      expect(stateOf(c).status, StoryPlaybackStatus.paused);
      expect(stateOf(c).pauseReasons, isEmpty);
      expect(events.last, StoryItemCompletedEvent(at(0, 0)));

      c.seekTo(ms * 500); // seeking back resumes
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
    });

    test('item overrides take precedence over the config', () async {
      final c = create(doc([
        [
          StoryItem(
            id: 'a',
            duration: const FixedItemDuration(s),
            playback: const StoryItemPlaybackConfiguration(autoAdvance: false),
          ),
          fixed('b', s),
        ],
      ]));
      c.play();
      await flush();
      harness.advance(s);
      await flush();
      expect(c.currentItem?.id, 'a');
    });

    test('can stop at the end of each group', () async {
      final c = create(
        doc([
          [fixed('a', s)],
          [fixed('b', s)],
        ]),
        config: const StoryPlaybackConfig(continueToNextGroup: false),
      );
      c.play();
      await flush();
      harness.advance(s);
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.completed);
      expect(c.location, at(0, 0));
    });

    test('loops back to the first item', () async {
      final c = create(
        doc([
          [fixed('a', s), fixed('b', s)],
        ]),
        config: const StoryPlaybackConfig(loop: true),
      );
      c.play();
      await flush();
      harness.advance(s);
      await flush();
      harness.advance(s);
      await flush();
      expect(c.currentItem?.id, 'a');
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
      expect(events, contains(const StoryPlaybackCompletedEvent()));
    });

    test('indefinite items never advance', () async {
      final c = create(doc([
        [StoryItem(id: 'a', duration: const IndefiniteItemDuration())],
      ]));
      c.play();
      await flush();
      harness.run(s * 60, step: s);
      expect(stateOf(c).duration, isNull);
      expect(stateOf(c).progress, 0);
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
    });
  });

  group('navigation', () {
    late StoryController c;

    setUp(() async {
      c = create(doc([
        [fixed('a'), fixed('b')],
        [fixed('c'), fixed('d')],
        [fixed('e')],
      ]));
      c.play();
      await flush();
    });

    test('next and previous cross group boundaries', () async {
      c.next();
      expect(c.currentItem?.id, 'b');
      c.next();
      expect(c.currentItem?.id, 'c');
      c.previous();
      expect(c.currentItem?.id, 'b');
      c.previous();
      c.previous();
      expect(c.currentItem?.id, 'a', reason: 'restarts the first item');
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
    });

    test('next on the last item completes playback', () async {
      c.jumpToItem('e');
      c.next();
      expect(stateOf(c).status, StoryPlaybackStatus.completed);
      c.next(); // no effect
      expect(stateOf(c).status, StoryPlaybackStatus.completed);
    });

    test('group navigation', () {
      c.next();
      c.nextGroup();
      expect(c.currentItem?.id, 'c');
      c.nextGroup();
      expect(c.currentItem?.id, 'e');
      c.previousGroup();
      expect(c.currentItem?.id, 'c');
      c.next();
      c.previousGroup();
      expect(c.currentItem?.id, 'a');
      c.previousGroup();
      expect(c.currentItem?.id, 'a', reason: 'restarts the first group');
    });

    test('jumps by location and id', () {
      c.jumpTo(at(1, 1));
      expect(c.currentItem?.id, 'd');
      c.jumpToItem('b');
      expect(c.location, at(0, 1));
      expect(() => c.jumpTo(at(9, 0)), throwsArgumentError);
      expect(() => c.jumpToItem('zzz'), throwsA(isA<StoryNotFoundException>()));
    });

    test('rapid navigation settles on the last target', () async {
      for (var i = 0; i < 20; i++) {
        c.next();
        c.previous();
      }
      c.jumpToItem('d');
      await flush();
      expect(c.currentItem?.id, 'd');
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
      expect(stateOf(c).position, Duration.zero);
    });

    test('previous after completion re-enters playback', () async {
      c.jumpToItem('e');
      c.next();
      c.previous();
      await flush();
      expect(c.currentItem?.id, 'd');
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
    });
  });

  test('navigation while idle moves without loading', () {
    final c = create(doc([
      [fixed('a'), fixed('b')],
    ]));
    c.next();
    expect(c.location, at(0, 1));
    expect(stateOf(c).status, StoryPlaybackStatus.idle);
    expect(events, isEmpty);
  });

  group('custom durations', () {
    test('are resolved by registered providers', () async {
      final provider = _Provider((item) async => const Duration(seconds: 7));
      final c = create(
        doc([
          [StoryItem(id: 'a', duration: CustomItemDuration('quiz'))],
        ]),
        durationProviders: {'quiz': provider},
      );
      c.play();
      await flush();
      expect(stateOf(c).duration, s * 7);
      expect(provider.items.single.id, 'a');
    });

    test('a null result means indefinite', () async {
      final c = create(
        doc([
          [StoryItem(id: 'a', duration: CustomItemDuration('quiz'))],
        ]),
        durationProviders: {'quiz': _Provider((_) => null)},
      );
      c.play();
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
      expect(stateOf(c).duration, isNull);
    });

    test('stale provider results are discarded', () async {
      final pending = Completer<Duration?>();
      final c = create(
        doc([
          [
            StoryItem(id: 'slow', duration: CustomItemDuration('slow')),
            fixed('b', s * 3),
          ],
        ]),
        durationProviders: {'slow': _Provider((_) => pending.future)},
      );
      c.play();
      await flush();
      c.next();
      await flush();
      pending.complete(const Duration(seconds: 99));
      await flush();
      expect(c.currentItem?.id, 'b');
      expect(stateOf(c).duration, s * 3);
    });
  });

  group('errors', () {
    StoryDocument withMissingProvider() => doc([
          [StoryItem(id: 'bad', duration: CustomItemDuration('missing'))],
          [fixed('ok')],
        ]);

    test('stop policy enters the error state', () async {
      final c = create(withMissingProvider());
      c.play();
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.error);
      expect(stateOf(c).error, isA<ConfigurationException>());
      expect(events.last, isA<StoryPlaybackErrorEvent>());
      expect(harness.ticker!.isActive, isFalse);
    });

    test('play retries after an error', () async {
      var calls = 0;
      final c = create(
        doc([
          [StoryItem(id: 'a', duration: CustomItemDuration('flaky'))],
        ]),
        durationProviders: {
          'flaky': _Provider((_) {
            if (calls++ == 0) throw StateError('first call fails');
            return const Duration(seconds: 2);
          }),
        },
      );
      c.play();
      await flush();
      expect(
          stateOf(c).error,
          isA<PlaybackException>()
              .having((e) => e.cause, 'cause', isA<StateError>()));
      c.play();
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
      expect(stateOf(c).error, isNull);
    });

    test('skip policy moves on to the next item', () async {
      final c = create(
        withMissingProvider(),
        config: const StoryPlaybackConfig(errorPolicy: StoryErrorPolicy.skip),
      );
      c.play();
      await flush();
      expect(c.currentItem?.id, 'ok');
      expect(stateOf(c).status, StoryPlaybackStatus.playing);
      expect(events.whereType<StoryPlaybackErrorEvent>(), hasLength(1));
    });

    test('skip policy stops when every item fails', () async {
      final c = create(
        doc([
          [
            StoryItem(id: 'a', duration: CustomItemDuration('missing')),
            StoryItem(id: 'b', duration: CustomItemDuration('missing')),
          ],
        ]),
        config: const StoryPlaybackConfig(
          errorPolicy: StoryErrorPolicy.skip,
          loop: true,
        ),
      );
      c.play();
      await flush();
      expect(stateOf(c).status, StoryPlaybackStatus.error);
    });
  });

  group('select', () {
    test('notifies only when the selected value changes', () async {
      final c = create(doc([
        [fixed('a', s * 10), fixed('b')],
      ]));
      final itemIndex = c.select((state) => state.itemIndex);
      var notifications = 0;
      void listener() => notifications++;
      itemIndex.addListener(listener);

      c.play();
      await flush();
      harness.run(s * 3);
      expect(notifications, 0, reason: 'progress ticks are filtered out');

      c.next();
      expect(notifications, 1);
      expect(itemIndex.value, 1);
      itemIndex.removeListener(listener);
      (itemIndex as ChangeNotifier).dispose();
    });
  });

  group('dispose', () {
    test('stops the ticker and rejects further use', () async {
      final c = create(doc([
        [fixed('a')],
      ]));
      c.play();
      await flush();
      await c.dispose();
      expect(c.isDisposed, isTrue);
      expect(harness.ticker!.disposed, isTrue);
      expect(c.play, throwsA(isA<ControllerDisposedException>()));
      expect(() => c.seekTo(s), throwsA(isA<ControllerDisposedException>()));
      await c.dispose(); // idempotent
    });

    test('ignores async work that finishes after disposal', () async {
      final pending = Completer<Duration?>();
      final c = create(
        doc([
          [StoryItem(id: 'a', duration: CustomItemDuration('slow'))],
        ]),
        durationProviders: {'slow': _Provider((_) => pending.future)},
      );
      c.play();
      await c.dispose();
      pending.complete(s);
      await flush(); // must not throw
    });
  });
}

final class _Provider implements StoryDurationProvider {
  _Provider(this._resolve);

  final FutureOr<Duration?> Function(StoryItem item) _resolve;
  final List<StoryItem> items = [];

  @override
  FutureOr<Duration?> resolve(StoryItem item, CustomItemDuration duration) {
    items.add(item);
    return _resolve(item);
  }
}
