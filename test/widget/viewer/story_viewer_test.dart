import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/viewer.dart';

import '../../helpers/engine_fakes.dart';

const s = Duration(seconds: 1);

StoryItem textItem(String id, {StoryItemDuration? duration}) => StoryItem(
      id: id,
      duration: duration ?? const FixedItemDuration(Duration(seconds: 5)),
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
      StoryGroup(
          id: 'alice', title: 'Alice', items: [textItem('a1'), textItem('a2')]),
      StoryGroup(id: 'bob', title: 'Bob', items: [textItem('b1')]),
    ]);

/// Hosts a viewer in the 800×600 test surface.
class _Host extends StatelessWidget {
  const _Host({required this.child, this.textDirection = TextDirection.ltr});

  final Widget child;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(textDirection: textDirection, child: child),
      );
}

/// Counts how often a custom element is built.
final class _CountingRenderer extends StoryElementRenderer<CustomElement> {
  int builds = 0;

  @override
  String get id => 'custom:counter';

  @override
  Widget buildElement(BuildContext context, CustomElement element,
      StoryRenderContext renderContext) {
    builds++;
    return const SizedBox.expand();
  }
}

final class _Pending implements StoryDurationProvider {
  final Completer<Duration?> completer = Completer();

  @override
  FutureOr<Duration?> resolve(StoryItem item, CustomItemDuration duration) =>
      completer.future;
}

final class _Failing implements StoryDurationProvider {
  int calls = 0;

  @override
  FutureOr<Duration?> resolve(StoryItem item, CustomItemDuration duration) {
    calls++;
    if (calls == 1) throw StateError('boom');
    return const Duration(seconds: 5);
  }
}

void main() {
  final harness = EngineHarness();
  final controllers = <StoryController>[];

  setUp(harness.reset);

  tearDown(() async {
    for (final controller in controllers) {
      await controller.dispose();
    }
    controllers.clear();
  });

  StoryController controllerFor(
    StoryDocument document, {
    Map<String, StoryDurationProvider> durationProviders = const {},
  }) {
    final controller = StoryController(
      document: document,
      clock: harness.clock,
      tickerFactory: harness.createTicker,
      durationProviders: durationProviders,
    );
    controllers.add(controller);
    return controller;
  }

  Future<StoryController> pumpViewer(
    WidgetTester tester, {
    StoryDocument? document,
    StoryViewerConfig config = const StoryViewerConfig(),
    VoidCallback? onDismiss,
    VoidCallback? onComplete,
    StoryViewerBuilder? loadingBuilder,
    StoryViewerErrorBuilder? errorBuilder,
    StoryViewerLayoutBuilder? layoutBuilder,
    StoryRendererRegistry? registry,
    Map<String, StoryDurationProvider> durationProviders = const {},
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final controller = controllerFor(document ?? sampleDoc(),
        durationProviders: durationProviders);
    await tester.pumpWidget(_Host(
      textDirection: textDirection,
      child: StoryViewer.controller(
        controller: controller,
        config: config,
        onDismiss: onDismiss,
        onComplete: onComplete,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
        layoutBuilder: layoutBuilder,
        registry: registry,
      ),
    ));
    await tester.pump();
    return controller;
  }

  testWidgets('autoplays and shows the item, title, and progress',
      (tester) async {
    final controller = await pumpViewer(tester);
    expect(controller.state.value.status, StoryPlaybackStatus.playing);
    expect(find.text('Item a1'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.bySemanticsLabel('Story 1 of 2'), findsOneWidget);
  });

  testWidgets('autoplay can be turned off', (tester) async {
    final controller = await pumpViewer(tester,
        config: const StoryViewerConfig(autoplay: false));
    expect(controller.state.value.status, StoryPlaybackStatus.idle);
  });

  testWidgets('taps navigate: leading side back, elsewhere forward',
      (tester) async {
    final controller = await pumpViewer(tester);
    await tester.tapAt(const Offset(600, 300));
    await tester.pump();
    expect(find.text('Item a2'), findsOneWidget);
    expect(find.bySemanticsLabel('Story 2 of 2'), findsOneWidget);

    await tester.tapAt(const Offset(600, 300));
    await tester.pump();
    expect(find.text('Item b1'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    expect(controller.currentItem?.id, 'a2');
  });

  testWidgets('taps are mirrored for right-to-left text', (tester) async {
    final controller =
        await pumpViewer(tester, textDirection: TextDirection.rtl);
    await tester.tapAt(const Offset(100, 300)); // trailing side in RTL
    await tester.pump();
    expect(controller.currentItem?.id, 'a2');
  });

  testWidgets('press and hold pauses until release', (tester) async {
    final controller = await pumpViewer(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(controller.state.value.pauseReasons, {StoryPauseReason.user});
    await gesture.up();
    await tester.pump();
    expect(controller.state.value.pauseReasons, isEmpty);
    expect(controller.currentItem?.id, 'a1', reason: 'a hold is not a tap');
  });

  testWidgets('horizontal swipes move between groups', (tester) async {
    final controller = await pumpViewer(tester);
    await tester.dragFrom(const Offset(600, 300), const Offset(-300, 0));
    await tester.pump();
    expect(controller.location?.groupIndex, 1);
    await tester.dragFrom(const Offset(200, 300), const Offset(300, 0));
    await tester.pump();
    expect(controller.location?.groupIndex, 0);
    expect(controller.state.value.pauseReasons, isEmpty,
        reason: 'the drag hold is released');
  });

  testWidgets('dragging down dismisses, and the close button appears',
      (tester) async {
    var dismissed = 0;
    await pumpViewer(tester, onDismiss: () => dismissed++);
    await tester.dragFrom(const Offset(400, 200), const Offset(0, 200));
    await tester.pump();
    expect(dismissed, 1);

    await tester.tap(find.bySemanticsLabel('Close'));
    expect(dismissed, 2);
  });

  testWidgets('without onDismiss there is no close button', (tester) async {
    await pumpViewer(tester);
    expect(find.byType(StoryCloseButton), findsNothing);
  });

  testWidgets('keyboard shortcuts', (tester) async {
    var dismissed = 0;
    final controller = await pumpViewer(tester, onDismiss: () => dismissed++);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.currentItem?.id, 'a2');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.currentItem?.id, 'a1');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(controller.state.value.pauseReasons, {StoryPauseReason.user});
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(controller.state.value.pauseReasons, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismissed, 1);
  });

  testWidgets('navigation is available to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpViewer(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Next story')),
      matchesSemantics(label: 'Next story', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Previous story')),
      matchesSemantics(
          label: 'Previous story', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('progress ticks repaint without rebuilding the content',
      (tester) async {
    final counter = _CountingRenderer();
    final registry = StoryRendererRegistry.withDefaults([counter]);
    addTearDown(registry.dispose);
    final document = StoryDocument(id: 'd', groups: [
      StoryGroup(id: 'g', items: [
        StoryItem(
          id: 'i',
          duration: const FixedItemDuration(Duration(seconds: 10)),
          elements: [
            CustomElement(
              id: 'c',
              transform: const StoryTransform(
                  position: StoryPoint(100, 100), size: StorySize(10, 10)),
              customType: 'counter',
            ),
          ],
        ),
      ]),
    ]);
    final controller =
        await pumpViewer(tester, document: document, registry: registry);
    final buildsAfterStart = counter.builds;

    for (var i = 0; i < 20; i++) {
      harness.advance(const Duration(milliseconds: 100));
      await tester.pump();
    }
    expect(controller.state.value.position, s * 2);
    expect(counter.builds, buildsAfterStart);
  });

  test('progress segments fill by item', () {
    StoryPlaybackState state(int item, Duration position,
            {StoryPlaybackStatus status = StoryPlaybackStatus.playing}) =>
        StoryPlaybackState(
          itemIndex: item,
          position: position,
          duration: s * 4,
          status: status,
        );
    final playing = state(1, s);
    expect(
      [for (var i = 0; i < 3; i++) StoryProgressPainter.fillFor(playing, i)],
      [1, 0.25, 0],
    );
    final done = state(2, s * 4, status: StoryPlaybackStatus.completed);
    expect(StoryProgressPainter.fillFor(done, 2), 1);
  });

  testWidgets('shows the loading overlay while an item prepares',
      (tester) async {
    final pending = _Pending();
    await pumpViewer(
      tester,
      document: StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [
          textItem('slow', duration: CustomItemDuration('slow')),
        ]),
      ]),
      durationProviders: {'slow': pending},
      loadingBuilder: (context, controller) => const Text('loading…'),
    );
    expect(find.text('loading…'), findsOneWidget);
    pending.completer.complete(s * 5);
    await tester.pump();
    await tester.pump();
    expect(find.text('loading…'), findsNothing);
  });

  testWidgets('shows the error overlay and retries on tap', (tester) async {
    final failing = _Failing();
    final controller = await pumpViewer(
      tester,
      document: StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [
          textItem('x', duration: CustomItemDuration('flaky')),
        ]),
      ]),
      durationProviders: {'flaky': failing},
    );
    await tester.pump();
    expect(controller.state.value.status, StoryPlaybackStatus.error);
    expect(find.text("Couldn't load this story"), findsOneWidget);

    await tester.tap(find.text('Tap to retry'));
    await tester.pump();
    await tester.pump();
    expect(controller.state.value.status, StoryPlaybackStatus.playing);
    expect(find.text("Couldn't load this story"), findsNothing);
  });

  testWidgets('custom error builder receives the error', (tester) async {
    await pumpViewer(
      tester,
      document: StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [
          textItem('x', duration: CustomItemDuration('missing')),
        ]),
      ]),
      errorBuilder: (context, controller, error) =>
          Text('error: ${error.runtimeType}'),
    );
    await tester.pump();
    expect(find.text('error: ConfigurationException'), findsOneWidget);
  });

  testWidgets('calls onComplete at the end', (tester) async {
    var completed = 0;
    final controller = await pumpViewer(tester, onComplete: () => completed++);
    controller.jumpToItem('b1');
    controller.next();
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('layoutBuilder replaces the arrangement', (tester) async {
    await pumpViewer(
      tester,
      layoutBuilder: (context, parts) => Column(children: [
        const Text('custom layout'),
        Expanded(child: parts.content),
      ]),
    );
    expect(find.text('custom layout'), findsOneWidget);
    expect(find.text('Item a1'), findsOneWidget);
    expect(find.byType(StoryProgressBar), findsNothing);
  });

  testWidgets('backgrounding pauses unless disabled', (tester) async {
    // Lifecycle changes must follow valid transitions.
    void background() {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    void foreground() {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    final controller = await pumpViewer(tester);
    background();
    expect(
        controller.state.value.pauseReasons, {StoryPauseReason.appBackground});
    foreground();
    expect(controller.state.value.pauseReasons, isEmpty);

    final unbound = await pumpViewer(tester,
        config: const StoryViewerConfig(pauseInBackground: false));
    background();
    expect(unbound.state.value.pauseReasons, isEmpty);
    foreground();
  });

  testWidgets('owns and disposes its controller when given a document',
      (tester) async {
    await tester.pumpWidget(_Host(child: StoryViewer(document: sampleDoc())));
    await tester.pump();
    expect(find.text('Item a1'), findsOneWidget);
    // Unmounting must stop the owned controller's timer.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('rejects invalid viewer configuration', () {
    expect(
      () => const StoryViewerConfig(previousTapFraction: 1.5).validate(),
      throwsA(isA<ConfigurationException>()),
    );
  });
}
