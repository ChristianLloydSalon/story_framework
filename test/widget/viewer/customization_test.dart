import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/viewer.dart';

import '../../helpers/engine_fakes.dart';

StoryItem textItem(String id) => StoryItem(
      id: id,
      duration: const FixedItemDuration(Duration(seconds: 5)),
      elements: [
        TextElement(
          id: '$id-text',
          transform: const StoryTransform(
              position: StoryPoint(540, 960), size: StorySize(800, 200)),
          text: 'Item $id',
        ),
      ],
    );

StoryDocument sampleDoc() => StoryDocument(id: 'd', groups: [
      StoryGroup(id: 'g1', title: 'One', items: [textItem('a'), textItem('b')]),
      StoryGroup(id: 'g2', title: 'Two', items: [textItem('c')]),
    ]);

class _Host extends StatelessWidget {
  const _Host({required this.child, this.disableAnimations = false});

  final Widget child;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQueryData(
            size: const Size(800, 600), disableAnimations: disableAnimations),
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      );
}

/// A double-tap handler that records where it fired.
final class _DoubleTapLike extends StoryGestureHandler {
  final List<Offset> taps = [];

  @override
  String get id => 'like';

  @override
  Set<StoryGestureKind> get kinds => const {StoryGestureKind.doubleTap};

  @override
  bool canHandle(StoryGestureContext context) =>
      context.event is StoryDoubleTapEvent;

  @override
  void handle(StoryGestureContext context) {
    final event = context.event;
    if (event is StoryDoubleTapEvent) taps.add(event.position);
  }
}

/// Claims vertical drags ahead of swipe-to-dismiss and records cancels.
final class _DragClaimer extends StoryGestureHandler {
  int handled = 0;
  int cancelled = 0;

  @override
  String get id => 'claimer';

  @override
  int get priority => 10;

  @override
  Set<StoryGestureKind> get kinds => const {StoryGestureKind.verticalDrag};

  @override
  bool canHandle(StoryGestureContext context) =>
      context.event is StoryDragStartEvent;

  @override
  void handle(StoryGestureContext context) => handled++;

  @override
  void cancel(StoryGestureContext context) => cancelled++;
}

/// Records every transition frame it builds.
final class _SpyTransition extends StoryTransition {
  final List<StoryTransitionDirection> directions = [];

  @override
  String get id => 'spy';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) {
    directions.add(frame.direction);
    return Stack(children: [frame.outgoing, frame.incoming]);
  }
}

void main() {
  final harness = EngineHarness();
  final controllers = <StoryController>[];
  final registries = <ChangeNotifier>[];

  setUp(harness.reset);
  tearDown(() async {
    for (final c in controllers) {
      await c.dispose();
    }
    for (final r in registries) {
      r.dispose();
    }
    controllers.clear();
    registries.clear();
  });

  StoryController controllerFor(StoryDocument document) {
    final c = StoryController(
      document: document,
      clock: harness.clock,
      tickerFactory: harness.createTicker,
    );
    controllers.add(c);
    return c;
  }

  T track<T extends ChangeNotifier>(T registry) {
    registries.add(registry);
    return registry;
  }

  Future<StoryController> pumpViewer(
    WidgetTester tester, {
    StoryDocument? document,
    StoryViewerConfig config = const StoryViewerConfig(),
    StoryGestureRegistry? gestures,
    StoryTransitionRegistry? transitions,
    List<StoryOverlay> overlays = const [],
    bool disableAnimations = false,
    VoidCallback? onDismiss,
  }) async {
    final controller = controllerFor(document ?? sampleDoc());
    await tester.pumpWidget(_Host(
      disableAnimations: disableAnimations,
      child: StoryViewer.controller(
        controller: controller,
        config: config,
        gestureRegistry: gestures,
        transitionRegistry: transitions,
        overlays: overlays,
        onDismiss: onDismiss,
      ),
    ));
    await tester.pump();
    return controller;
  }

  group('gestures', () {
    testWidgets('custom double-tap handler coexists with tap navigation',
        (tester) async {
      final like = _DoubleTapLike();
      final gestures =
          track(StoryGestureRegistry.withDefaults(handlers: [like]));
      final controller = await pumpViewer(tester, gestures: gestures);

      await tester.tapAt(const Offset(600, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(600, 300));
      await tester.pump(kDoubleTapTimeout);
      expect(like.taps, [const Offset(600, 300)]);
      expect(controller.currentItem?.id, 'a',
          reason: 'a double tap is not two navigation taps');

      await tester.tapAt(const Offset(600, 300));
      await tester.pump(kDoubleTapTimeout);
      expect(controller.currentItem?.id, 'b');
    });

    testWidgets('disabling a handler at runtime takes effect', (tester) async {
      final gestures = track(StoryGestureRegistry.withDefaults());
      final controller = await pumpViewer(tester, gestures: gestures);
      gestures.setEnabled(StoryTapNavigationHandler.handlerId, enabled: false);
      await tester.pump();
      await tester.tapAt(const Offset(600, 300));
      await tester.pump();
      expect(controller.currentItem?.id, 'a');
    });

    testWidgets('a higher-priority handler wins the drag', (tester) async {
      var dismissed = 0;
      final claimer = _DragClaimer();
      final gestures =
          track(StoryGestureRegistry.withDefaults(handlers: [claimer]));
      await pumpViewer(tester,
          gestures: gestures, onDismiss: () => dismissed++);
      await tester.dragFrom(const Offset(400, 200), const Offset(0, 250));
      await tester.pump();
      expect(dismissed, 0);
      expect(claimer.handled, greaterThanOrEqualTo(2),
          reason: 'start, updates, and end go to the owner');
    });

    testWidgets('removing the viewer mid-drag cancels the owner',
        (tester) async {
      final claimer = _DragClaimer();
      final gestures = track(StoryGestureRegistry([claimer]));
      await pumpViewer(tester, gestures: gestures);
      final gesture = await tester.startGesture(const Offset(400, 200));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(claimer.handled, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      expect(claimer.cancelled, 1);
      await gesture.up();
    });

    testWidgets('config switches disable default gestures', (tester) async {
      final controller = await pumpViewer(
        tester,
        config: const StoryViewerConfig(swipeBetweenGroups: false),
      );
      await tester.dragFrom(const Offset(600, 300), const Offset(-300, 0));
      await tester.pump();
      expect(controller.location?.groupIndex, 0);
    });
  });

  group('transitions', () {
    testWidgets('group changes animate with both items visible',
        (tester) async {
      final controller = await pumpViewer(tester);
      controller.nextGroup();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Item a'), findsOneWidget);
      expect(find.text('Item c'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Item a'), findsNothing);
      expect(find.text('Item c'), findsOneWidget);
    });

    testWidgets('items cut by default and use their own transition',
        (tester) async {
      final spy = _SpyTransition();
      final transitions = track(StoryTransitionRegistry.withDefaults([spy]));
      final document = StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [
          textItem('a'),
          textItem('b'),
          StoryItem(
            id: 'c',
            transition: StoryTransitionConfiguration(type: 'spy'),
            elements: textItem('c').elements,
          ),
        ]),
      ]);
      final controller = await pumpViewer(tester,
          document: document, transitions: transitions);

      controller.next();
      await tester.pump();
      expect(find.text('Item a'), findsNothing, reason: 'items cut');

      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(spy.directions, isNotEmpty);
      expect(spy.directions.first, StoryTransitionDirection.forward);
      await tester.pumpAndSettle();
    });

    testWidgets('backward navigation reports a backward direction',
        (tester) async {
      final spy = _SpyTransition();
      final transitions = track(StoryTransitionRegistry.withDefaults([spy]));
      final controller = await pumpViewer(
        tester,
        transitions: transitions,
        config: const StoryViewerConfig(
          groupTransition: StoryTransitionConfiguration.preset('spy'),
        ),
      );
      controller.nextGroup();
      await tester.pumpAndSettle();
      spy.directions.clear();
      controller.previousGroup();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(spy.directions.first, StoryTransitionDirection.backward);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion swaps in the reduced transition',
        (tester) async {
      final spy = _SpyTransition();
      final transitions = track(StoryTransitionRegistry.withDefaults([spy]));
      final controller = await pumpViewer(
        tester,
        transitions: transitions,
        disableAnimations: true,
        config: const StoryViewerConfig(
          groupTransition: StoryTransitionConfiguration.preset('spy'),
        ),
      );
      controller.nextGroup();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(spy.directions, isEmpty);
      expect(find.byType(FadeTransition), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('every preset renders mid-animation in both directions',
        (tester) async {
      for (final preset in storyTransitionPresets) {
        for (final direction in StoryTransitionDirection.values) {
          await tester.pumpWidget(_Host(
            child: StoryTransitionSwitcher(
              childKey: 'old',
              transition: preset,
              duration: const Duration(milliseconds: 300),
              direction: direction,
              child: const Text('old'),
            ),
          ));
          await tester.pumpWidget(_Host(
            child: StoryTransitionSwitcher(
              childKey: 'new',
              transition: preset,
              duration: const Duration(milliseconds: 300),
              direction: direction,
              child: const Text('new'),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 150));
          expect(tester.takeException(), isNull, reason: preset.id);
          expect(find.text('new'), findsOneWidget, reason: preset.id);
          await tester.pumpAndSettle();
          expect(find.text('old'), findsNothing, reason: preset.id);
        }
      }
    });

    testWidgets('the incoming child keeps its state after the transition',
        (tester) async {
      await tester.pumpWidget(
          const _FadeSwitcher(childKey: 'a', child: _Counter(label: 'a')));
      await tester.pumpWidget(
          const _FadeSwitcher(childKey: 'b', child: _Counter(label: 'b')));
      await tester.pump(const Duration(milliseconds: 50));
      final during = tester.state<_CounterState>(find.byType(_Counter).last);
      await tester.pumpAndSettle();
      final after = tester.state<_CounterState>(find.byType(_Counter));
      expect(identical(during, after), isTrue);
    });

    test('unknown transitions fall back to a cut', () {
      final registry = StoryTransitionRegistry.withDefaults();
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      try {
        expect(registry.resolve('warp'), isA<StoryNoTransition>());
        registry.resolve('warp');
      } finally {
        FlutterError.onError = previous;
      }
      expect(reported, hasLength(1), reason: 'reported once per id');
      expect(registry.resolve('cube'), isA<StoryCubeTransition>());
      registry.dispose();
    });

    test('curves resolve by name with a safe fallback', () {
      expect(storyCurveNamed('linear'), Curves.linear);
      expect(storyCurveNamed('nope'), Curves.easeInOut);
    });
  });

  group('overlays', () {
    testWidgets('are placed, ordered, and consume their own taps',
        (tester) async {
      var liked = 0;
      final controller = await pumpViewer(tester, overlays: [
        StoryOverlay(
          id: 'like',
          alignment: AlignmentDirectional.bottomEnd,
          padding: const EdgeInsets.all(16),
          builder: (context, controller) => GestureDetector(
            onTap: () => liked++,
            child: const SizedBox(width: 60, height: 60, child: Text('♥')),
          ),
        ),
        StoryOverlay(
          id: 'badge',
          zIndex: 200,
          alignment: AlignmentDirectional.center,
          interactive: false,
          builder: (context, controller) => const Text('Sponsored'),
        ),
      ]);
      final heart = tester.getRect(find.text('♥'));
      expect(heart.right, lessThanOrEqualTo(800 - 16));
      expect(heart.bottom, lessThanOrEqualTo(600 - 16));

      await tester.tap(find.text('♥'));
      await tester.pump();
      expect(liked, 1);
      expect(controller.currentItem?.id, 'a', reason: 'overlay consumed it');

      await tester.tap(find.text('Sponsored'), warnIfMissed: false);
      await tester.pump();
      expect(controller.currentItem?.id, 'b',
          reason: 'non-interactive overlays pass taps through');
    });

    testWidgets('visibility follows playback state with lifecycle callbacks',
        (tester) async {
      final events = <String>[];
      final controller = await pumpViewer(tester, overlays: [
        StoryOverlay(
          id: 'paused',
          alignment: AlignmentDirectional.center,
          visibleWhen: (state) =>
              state.pauseReasons.contains(StoryPauseReason.user),
          onShow: () => events.add('show'),
          onHide: () => events.add('hide'),
          builder: (context, controller) => const Text('Paused'),
        ),
      ]);
      double opacity() => tester
          .widget<FadeTransition>(find.ancestor(
              of: find.text('Paused'), matching: find.byType(FadeTransition)))
          .opacity
          .value;
      await tester.pumpAndSettle();
      expect(opacity(), 0);

      controller.pause();
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      controller.play();
      await tester.pumpAndSettle();
      expect(opacity(), 0);
      expect(events, ['show', 'hide']);
    });

    testWidgets('pauseWhileTouched holds playback during a press',
        (tester) async {
      final controller = await pumpViewer(tester, overlays: [
        StoryOverlay(
          id: 'reply',
          alignment: AlignmentDirectional.bottomCenter,
          pauseWhileTouched: true,
          builder: (context, controller) =>
              const SizedBox(width: 200, height: 40, child: Text('Reply')),
        ),
      ]);
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Reply')));
      await tester.pump();
      expect(controller.state.value.pauseReasons, {StoryPauseReason.external});
      await gesture.up();
      await tester.pump();
      expect(controller.state.value.pauseReasons, isEmpty);
    });

    testWidgets('app overlays below z-index 100 sit under the top bar',
        (tester) async {
      await pumpViewer(tester, overlays: [
        StoryOverlay(
          id: 'below',
          zIndex: 50,
          builder: (context, controller) => const Text('below'),
        ),
        StoryOverlay(
          id: 'above',
          zIndex: 150,
          builder: (context, controller) => const Text('above'),
        ),
      ]);
      final layer =
          tester.widget<StoryOverlayLayer>(find.byType(StoryOverlayLayer));
      final ids = layer.overlays.map((o) => o.id).toList();
      expect(ids, containsAll(['story.top', 'story.footer', 'below', 'above']));
      // Paint order follows z-index: below < top bar < above.
      final texts = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(StoryOverlayLayer), matching: find.byType(Text)))
          .map((t) => t.data)
          .toList();
      expect(texts.indexOf('below'), lessThan(texts.indexOf('One')));
      expect(texts.indexOf('One'), lessThan(texts.indexOf('above')));
    });
  });
}

class _FadeSwitcher extends StatelessWidget {
  const _FadeSwitcher({required this.childKey, required this.child});

  final Object childKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => _Host(
        child: StoryTransitionSwitcher(
          childKey: childKey,
          transition: const StoryFadeTransition(),
          duration: const Duration(milliseconds: 100),
          child: child,
        ),
      );
}

class _Counter extends StatefulWidget {
  const _Counter({required this.label});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  Widget build(BuildContext context) => Text(widget.label);
}
