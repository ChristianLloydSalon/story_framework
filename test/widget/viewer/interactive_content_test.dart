import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/viewer.dart';

import '../../fixtures/sample_document.dart';
import '../../helpers/engine_fakes.dart';

InteractiveElement elementById(String id) =>
    sampleInteractiveElements().firstWhere((e) => e.id == id);

/// A document with one item holding [elements], plus a second item so
/// navigation is observable.
StoryDocument docWith(List<StoryElement> elements) =>
    StoryDocument(id: 'd', groups: [
      StoryGroup(id: 'g', items: [
        StoryItem(
          id: 'first',
          duration: const FixedItemDuration(Duration(seconds: 10)),
          elements: elements,
        ),
        StoryItem(id: 'second'),
      ]),
    ]);

/// Centers [element] on the canvas with a large box, for easy tapping.
InteractiveElement centered(InteractiveElement element) =>
    element.copyWith(transform: box(540, 960, 900, 900));

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
  final events = <StoryInteractionEvent>[];

  setUp(() {
    harness.reset();
    events.clear();
  });
  tearDown(() async {
    for (final c in controllers) {
      await c.dispose();
    }
    controllers.clear();
  });

  Future<StoryController> pumpViewer(
    WidgetTester tester,
    StoryDocument document, {
    StoryInteractionController? interactions,
  }) async {
    final controller = StoryController(
      document: document,
      clock: harness.clock,
      tickerFactory: harness.createTicker,
    );
    controllers.add(controller);
    await tester.pumpWidget(_Host(
      child: StoryViewer.controller(
        controller: controller,
        interactionController: interactions,
        onInteraction: events.add,
      ),
    ));
    await tester.pump();
    return controller;
  }

  testWidgets('voting in a poll does not navigate and shows results',
      (tester) async {
    final interactions = StoryInteractionController(
      onInteraction: events.add,
      initialStates: {
        'poll': StoryChoiceState(counts: const {'tea': 1, 'coffee': 3}),
      },
    );
    addTearDown(interactions.dispose);
    final controller = await pumpViewer(
      tester,
      docWith([centered(elementById('poll'))]),
      interactions: interactions,
    );

    await tester.tap(find.text('Tea'));
    await tester.pump();
    expect(controller.currentItem?.id, 'first', reason: 'no navigation');
    expect((events.single as StoryChoiceSelectedEvent).choiceId, 'tea');
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);

    // Taps outside the sticker still navigate.
    await tester.tapAt(const Offset(780, 580));
    await tester.pump();
    expect(controller.currentItem?.id, 'second');
  });

  testWidgets('the viewer owns an interaction controller when none is given',
      (tester) async {
    await pumpViewer(tester, docWith([centered(elementById('quiz'))]));
    await tester.tap(find.text('Rome'));
    await tester.pump();
    final event = events.single as StoryChoiceSelectedEvent;
    expect(event.isCorrect, isFalse);
    expect(find.text('✓'), findsOneWidget, reason: 'correct answer revealed');
  });

  testWidgets('choices are screen-reader buttons and keyboard-activatable',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpViewer(tester, docWith([centered(elementById('poll'))]));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Vote Coffee')),
      matchesSemantics(
        label: 'Vote Coffee',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );

    Focus.of(tester.element(find.text('Coffee'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect((events.single as StoryChoiceSelectedEvent).choiceId, 'coffee');
    semantics.dispose();
  });

  testWidgets('typing a reply holds playback, and sending reports it',
      (tester) async {
    final controller =
        await pumpViewer(tester, docWith([centered(elementById('question'))]));
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    expect(controller.state.value.pauseReasons, {StoryPauseReason.interaction});

    await tester.enterText(find.byType(EditableText), 'What camera?');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect((events.single as StoryQuestionRepliedEvent).text, 'What camera?');
    expect(find.text('Reply sent'), findsOneWidget);
    expect(controller.state.value.pauseReasons, isEmpty,
        reason: 'sending unfocuses the field');
  });

  testWidgets('dragging the slider holds playback and submits on release',
      (tester) async {
    final controller =
        await pumpViewer(tester, docWith([centered(elementById('slider'))]));
    final handle = tester.getCenter(find.text('🔥'));
    final gesture = await tester.startGesture(handle);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(controller.state.value.pauseReasons, {StoryPauseReason.interaction});
    await gesture.up();
    await tester.pump();
    expect(controller.state.value.pauseReasons, isEmpty);
    final value = (events.single as StorySliderSubmittedEvent).value;
    expect(value, greaterThan(0.5));
    expect(controller.currentItem?.id, 'first');
  });

  testWidgets('link and product taps are reported, not opened', (tester) async {
    await pumpViewer(
        tester,
        docWith([
          elementById('link').copyWith(transform: box(540, 600, 700, 200)),
          elementById('product').copyWith(transform: box(540, 1300, 700, 200)),
        ]));
    await tester.tap(find.text('Shop now'));
    await tester.tap(find.text('Mug'));
    await tester.pump();
    expect(events.map((e) => e.runtimeType),
        [StoryLinkTappedEvent, StoryProductTappedEvent]);
  });

  testWidgets('countdowns tick from the scope clock and toggle reminders',
      (tester) async {
    var now = DateTime.utc(2026, 12, 1, 8, 59, 50);
    final interactions = StoryInteractionController(onInteraction: events.add);
    addTearDown(interactions.dispose);
    final document = docWith([centered(elementById('countdown'))]);
    await tester.pumpWidget(_Host(
      child: StoryInteractionScope(
        controller: interactions,
        now: () => now,
        child: StoryItemView(
          document: document,
          item: document.groups.single.items.first,
        ),
      ),
    ));
    expect(find.text('00:00:10'), findsOneWidget);

    await tester.tap(find.text('🔔 Remind me'));
    await tester.pump();
    expect(find.text('🔔 Reminder set'), findsOneWidget);

    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ended'), findsOneWidget);
    expect(find.text('🔔 Reminder set'), findsNothing);
    expect((events.single as StoryCountdownReminderEvent).reminderSet, isTrue);
  });

  testWidgets('without a scope, interactive elements are inert previews',
      (tester) async {
    final document = docWith(sampleInteractiveElements()
        .where((e) => e.interaction is! StoryCustomInteraction)
        .toList());
    await tester.pumpWidget(_Host(
      child: StoryItemView(
        document: document,
        item: document.groups.single.items.first,
        mode: StoryRenderMode.editor,
      ),
    ));
    await tester.tap(find.text('Tea'), warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Tea or coffee?'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing,
        reason: 'no live text field in previews');
  });

  testWidgets('custom interactions render through app builders',
      (tester) async {
    final registry = StoryRendererRegistry.withDefaults();
    addTearDown(registry.dispose);
    registry.replace(StoryInteractiveRenderer(customBuilders: {
      'emoji-rain': (context, element, interaction, renderContext) =>
          Text('rain ${interaction.data['emoji']}'),
    }));
    final controller = StoryController(
      document: docWith([elementById('custom-interaction')]),
      clock: harness.clock,
      tickerFactory: harness.createTicker,
    );
    controllers.add(controller);
    await tester.pumpWidget(_Host(
      child: StoryViewer.controller(controller: controller, registry: registry),
    ));
    expect(find.text('rain 🎈'), findsOneWidget);
  });
}
