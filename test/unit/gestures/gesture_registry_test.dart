import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/viewer.dart';

import '../../helpers/engine_fakes.dart';

final class _Recorder extends StoryGestureHandler {
  _Recorder(
    this.id, {
    this.priority = 0,
    this.kinds = const {StoryGestureKind.tap},
    this.accepts = true,
  });

  @override
  final String id;
  @override
  final int priority;
  @override
  final Set<StoryGestureKind> kinds;
  final bool accepts;
  final List<StoryGestureEvent> handled = [];

  @override
  bool canHandle(StoryGestureContext context) => accepts;

  @override
  void handle(StoryGestureContext context) => handled.add(context.event);
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

  StoryController controller() {
    final c = StoryController(
      document: StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g1', items: [StoryItem(id: 'a'), StoryItem(id: 'b')]),
        StoryGroup(id: 'g2', items: [StoryItem(id: 'c')]),
      ]),
      clock: harness.clock,
      tickerFactory: harness.createTicker,
    );
    controllers.add(c);
    return c;
  }

  StoryGestureContext contextFor(
    StoryGestureEvent event,
    StoryController c, {
    TextDirection textDirection = TextDirection.ltr,
    VoidCallback? onDismiss,
  }) =>
      StoryGestureContext(
        event: event,
        controller: c,
        size: const Size(100, 200),
        textDirection: textDirection,
        onDismiss: onDismiss,
      );

  group('registry', () {
    test('rejects duplicates and requires explicit replacement', () {
      final registry = StoryGestureRegistry([_Recorder('a')]);
      expect(() => registry.register(_Recorder('a')),
          throwsA(isA<ConfigurationException>()));
      expect(() => registry.replace(_Recorder('missing')),
          throwsA(isA<ConfigurationException>()));
      expect(() => registry.setEnabled('missing', enabled: false),
          throwsA(isA<ConfigurationException>()));
      registry.dispose();
    });

    test('dispatches by priority, newest first on ties', () {
      final c = controller();
      final low = _Recorder('low');
      final tieOld = _Recorder('tie-old', priority: 5);
      final tieNew = _Recorder('tie-new', priority: 5);
      final registry = StoryGestureRegistry([low, tieOld, tieNew]);
      expect(registry.activeHandlers.map((h) => h.id),
          ['tie-new', 'tie-old', 'low']);

      final winner =
          registry.dispatch(contextFor(const StoryTapEvent(Offset.zero), c));
      expect(winner, same(tieNew));
      expect(tieOld.handled, isEmpty);
      expect(low.handled, isEmpty);
      registry.dispose();
    });

    test('skips handlers that decline or want other kinds', () {
      final c = controller();
      final declines = _Recorder('declines', priority: 9, accepts: false);
      final dragsOnly = _Recorder('drags', priority: 8, kinds: const {
        StoryGestureKind.verticalDrag,
      });
      final fallback = _Recorder('fallback');
      final registry = StoryGestureRegistry([declines, dragsOnly, fallback]);
      expect(
        registry.dispatch(contextFor(const StoryTapEvent(Offset.zero), c)),
        same(fallback),
      );
      expect(dragsOnly.handled, isEmpty);
      registry.dispose();
    });

    test('disabled handlers are skipped and drop out of active kinds', () {
      final c = controller();
      final doubleTap =
          _Recorder('double', kinds: const {StoryGestureKind.doubleTap});
      final registry = StoryGestureRegistry([doubleTap]);
      var notified = 0;
      registry.addListener(() => notified++);
      expect(registry.activeKinds, {StoryGestureKind.doubleTap});

      registry.setEnabled('double', enabled: false);
      expect(registry.isEnabled('double'), isFalse);
      expect(registry.activeKinds, isEmpty);
      expect(
        registry
            .dispatch(contextFor(const StoryDoubleTapEvent(Offset.zero), c)),
        isNull,
      );
      registry.setEnabled('double', enabled: false); // no change, no notify
      registry.setEnabled('double', enabled: true);
      expect(notified, 2);
      registry.dispose();
    });

    test('replace keeps position and enabled state', () {
      final registry = StoryGestureRegistry([_Recorder('a'), _Recorder('b')]);
      registry.setEnabled('a', enabled: false);
      registry.replace(_Recorder('a', priority: 3));
      expect(registry.ids, ['a', 'b']);
      expect(registry.isEnabled('a'), isFalse);
      expect(registry.unregister('a'), isA<_Recorder>());
      expect(registry.ids, ['b']);
      registry.dispose();
    });

    test('defaults register the built-in viewer gestures', () {
      final registry = StoryGestureRegistry.withDefaults();
      expect(registry.ids, [
        'tap-navigation',
        'hold-to-pause',
        'swipe-groups',
        'swipe-dismiss',
      ]);
      expect(registry.activeKinds, isNot(contains(StoryGestureKind.doubleTap)),
          reason: 'double tap would delay single taps');
      registry.dispose();
    });
  });

  group('default handlers', () {
    test('tap navigation splits by leading fraction, mirrored in RTL', () {
      final c = controller()..play();
      const handler = StoryTapNavigationHandler();
      handler.handle(contextFor(const StoryTapEvent(Offset(80, 10)), c));
      expect(c.currentItem?.id, 'b');
      handler.handle(contextFor(const StoryTapEvent(Offset(10, 10)), c));
      expect(c.currentItem?.id, 'a');
      // In RTL the right edge is leading, so a tap at x=90 goes back.
      c.next();
      handler.handle(contextFor(const StoryTapEvent(Offset(90, 10)), c,
          textDirection: TextDirection.rtl));
      expect(c.currentItem?.id, 'a');
    });

    test('hold to pause resumes on end and on cancel', () {
      final c = controller()..play();
      const handler = StoryHoldToPauseHandler();
      handler
          .handle(contextFor(const StoryLongPressStartEvent(Offset.zero), c));
      expect(c.state.value.pauseReasons, {StoryPauseReason.user});
      handler.handle(contextFor(const StoryLongPressEndEvent(Offset.zero), c));
      expect(c.state.value.pauseReasons, isEmpty);
      handler
          .handle(contextFor(const StoryLongPressStartEvent(Offset.zero), c));
      handler.cancel(contextFor(const StoryLongPressEndEvent(Offset.zero), c));
      expect(c.state.value.pauseReasons, isEmpty);
    });

    test('swipe groups holds during the drag and changes group on release', () {
      final c = controller()..play();
      const handler = StorySwipeGroupsHandler();
      handler.handle(contextFor(
          const StoryDragStartEvent(StoryDragAxis.horizontal, Offset.zero), c));
      expect(c.state.value.pauseReasons, {StoryPauseReason.navigationOverlay});
      handler.handle(contextFor(
          const StoryDragEndEvent(StoryDragAxis.horizontal,
              offset: -80, velocity: 0),
          c));
      expect(c.location?.groupIndex, 1);
      expect(c.state.value.pauseReasons, isEmpty);

      handler.handle(contextFor(
          const StoryDragStartEvent(StoryDragAxis.horizontal, Offset.zero), c));
      handler.cancel(contextFor(
          const StoryDragEndEvent(StoryDragAxis.horizontal,
              offset: 0, velocity: 0),
          c));
      expect(c.state.value.pauseReasons, isEmpty);
      expect(c.location?.groupIndex, 1, reason: 'cancel does not navigate');
    });

    test('swipe dismiss only claims drags when dismissible', () {
      final c = controller()..play();
      var dismissed = 0;
      const handler = StorySwipeDismissHandler(distance: 50);
      const start = StoryDragStartEvent(StoryDragAxis.vertical, Offset.zero);
      expect(handler.canHandle(contextFor(start, c)), isFalse);
      final ctx = contextFor(start, c, onDismiss: () => dismissed++);
      expect(handler.canHandle(ctx), isTrue);
      handler.handle(ctx);
      handler.handle(contextFor(
          const StoryDragEndEvent(StoryDragAxis.vertical,
              offset: 20, velocity: 0),
          c,
          onDismiss: () => dismissed++));
      expect(dismissed, 0);
      handler.handle(contextFor(
          const StoryDragEndEvent(StoryDragAxis.vertical,
              offset: 60, velocity: 0),
          c,
          onDismiss: () => dismissed++));
      expect(dismissed, 1);
    });
  });
}
