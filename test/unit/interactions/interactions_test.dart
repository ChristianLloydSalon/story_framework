import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/viewer.dart';

import '../../fixtures/sample_document.dart';
import '../../helpers/engine_fakes.dart';

InteractiveElement elementById(String id) =>
    sampleInteractiveElements().firstWhere((e) => e.id == id);

void main() {
  group('model', () {
    const codec = StoryDocumentCodec();

    test('every interaction kind round-trips', () {
      final document = sampleDocument();
      expect(codec.decode(codec.encode(document)), document);
      expect(const StoryDocumentValidator().validate(document).errors, isEmpty);
    });

    test('interactive elements are flagged interactive', () {
      expect(elementById('poll').isInteractive, isTrue);
      expect(
        TextElement(id: 't', transform: box(0, 0), text: 'x').isInteractive,
        isFalse,
      );
    });

    test('unknown interaction kinds are preserved like unknown elements', () {
      final document = codec.decode({
        'schemaVersion': 1,
        'id': 'd',
        'groups': [
          {
            'id': 'g',
            'items': [
              {
                'id': 'i',
                'elements': [
                  {
                    'type': 'interactive',
                    'id': 'future',
                    'interaction': {'kind': 'hologram', 'depth': 3},
                  },
                ],
              },
            ],
          },
        ],
      });
      final element = document.groups.single.items.single.elements.single;
      expect(element, isA<UnknownElement>());
      final json = codec.encode(document);
      expect(json.toString(), contains('hologram'));
    });

    test('validation catches broken interactions', () {
      StoryDocument withInteraction(StoryInteraction interaction) =>
          StoryDocument(id: 'd', groups: [
            StoryGroup(id: 'g', items: [
              StoryItem(id: 'i', elements: [
                InteractiveElement(
                    id: 'x', transform: box(0, 0), interaction: interaction),
              ]),
            ]),
          ]);
      Iterable<String> errors(StoryInteraction interaction) =>
          const StoryDocumentValidator()
              .validate(withInteraction(interaction))
              .errors
              .map((e) => e.path);
      const base = 'groups[0].items[0].elements[0].interaction';

      expect(
        errors(StoryPoll(
            question: 'Q', choices: const [StoryChoice(id: 'a', label: 'A')])),
        ['$base.choices'],
      );
      expect(
        errors(StoryPoll(question: 'Q', choices: const [
          StoryChoice(id: 'a', label: 'A'),
          StoryChoice(id: 'a', label: 'B'),
        ])),
        ['$base.choices[1].id'],
      );
      expect(
        errors(StoryQuiz(
          question: 'Q',
          choices: const [
            StoryChoice(id: 'a', label: 'A'),
            StoryChoice(id: 'b', label: 'B'),
          ],
          correctChoiceId: 'z',
        )),
        ['$base.correctChoiceId'],
      );
      expect(
        errors(StoryLink(url: Uri.parse('ftp://x'), label: 'Go')),
        ['$base.url'],
      );
    });
  });

  group('playback holds', () {
    final harness = EngineHarness();
    final controllers = <StoryController>[];
    setUp(harness.reset);
    tearDown(() async {
      for (final c in controllers) {
        await c.dispose();
      }
      controllers.clear();
    });

    Future<StoryController> playing() async {
      final c = StoryController(
        document: StoryDocument(id: 'd', groups: [
          StoryGroup(id: 'g', items: [StoryItem(id: 'i')]),
        ]),
        clock: harness.clock,
        tickerFactory: harness.createTicker,
      )..play();
      controllers.add(c);
      await flush();
      return c;
    }

    test('are counted per reason', () async {
      final c = await playing();
      final first = c.acquirePause(StoryPauseReason.interaction);
      final second = c.acquirePause(StoryPauseReason.interaction);
      expect(c.state.value.status, StoryPlaybackStatus.paused);
      first.release();
      first.release(); // idempotent
      expect(c.state.value.pauseReasons, {StoryPauseReason.interaction});
      second.release();
      expect(c.state.value.status, StoryPlaybackStatus.playing);
      expect(first.isActive, isFalse);
    });

    test('are not cleared by removePauseReason', () async {
      final c = await playing();
      final hold = c.acquirePause(StoryPauseReason.modal);
      c.removePauseReason(StoryPauseReason.modal);
      expect(c.state.value.pauseReasons, {StoryPauseReason.modal});
      hold.release();
      expect(c.state.value.pauseReasons, isEmpty);
    });

    test('become inactive when the controller is disposed', () async {
      final c = await playing();
      final hold = c.acquirePause(StoryPauseReason.interaction);
      await c.dispose();
      expect(hold.isActive, isFalse);
      hold.release(); // must not throw
    });
  });

  group('StoryInteractionController', () {
    final events = <StoryInteractionEvent>[];
    setUp(events.clear);

    StoryInteractionController create({
      Map<String, StoryInteractionState> initialStates = const {},
      bool allowChangingAnswers = false,
    }) =>
        StoryInteractionController(
          initialStates: initialStates,
          onInteraction: events.add,
          allowChangingAnswers: allowChangingAnswers,
        );

    test('a vote updates known results and is final by default', () {
      final poll = elementById('poll');
      final controller = create(initialStates: {
        'poll': StoryChoiceState(counts: const {'tea': 3, 'coffee': 1}),
      });
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.selectChoice(poll, 'i4', 'coffee'), isTrue);
      final state = controller.stateOf<StoryChoiceState>('poll');
      expect(state?.selectedChoiceId, 'coffee');
      expect(state?.counts, {'tea': 3, 'coffee': 2});
      expect(state?.shareOf('tea'), 0.6);
      expect(notified, 1);

      expect(controller.selectChoice(poll, 'i4', 'tea'), isFalse);
      expect(controller.selectChoice(poll, 'i4', 'nope'), isFalse);
      expect(events, hasLength(1));
      final event = events.single as StoryChoiceSelectedEvent;
      expect(event.choiceId, 'coffee');
      expect(event.itemId, 'i4');
      expect(event.isCorrect, isNull);
    });

    test('changing a vote moves it when allowed', () {
      final poll = elementById('poll');
      final controller = create(
        allowChangingAnswers: true,
        initialStates: {
          'poll': StoryChoiceState(counts: const {'tea': 1, 'coffee': 1}),
        },
      );
      controller.selectChoice(poll, 'i4', 'tea');
      controller.selectChoice(poll, 'i4', 'coffee');
      expect(controller.stateOf<StoryChoiceState>('poll')?.counts,
          {'tea': 1, 'coffee': 2});
    });

    test('quiz answers report correctness', () {
      final controller = create();
      controller.selectChoice(elementById('quiz'), 'i4', 'rome');
      expect((events.single as StoryChoiceSelectedEvent).isCorrect, isFalse);
    });

    test('slider ratings are clamped and final by default', () {
      final slider = elementById('slider');
      final controller = create();
      expect(controller.submitSlider(slider, 'i4', 1.7), isTrue);
      expect(controller.stateOf<StorySliderState>('slider')?.value, 1);
      expect(controller.submitSlider(slider, 'i4', 0.2), isFalse);
      expect((events.single as StorySliderSubmittedEvent).value, 1);
    });

    test('question replies, reminders, links, products, custom actions', () {
      final controller = create();
      expect(controller.replyToQuestion(elementById('question'), 'i4', '   '),
          isFalse);
      expect(controller.replyToQuestion(elementById('question'), 'i4', ' Hi '),
          isTrue);
      expect(controller.stateOf<StoryQuestionState>('question')?.replies, 1);
      expect(controller.toggleReminder(elementById('countdown'), 'i4'), isTrue);
      controller.tapLink(elementById('link'), 'i4');
      controller.tapProduct(elementById('product'), 'i4');
      controller.reportCustom(elementById('custom-interaction'), 'i4', 'pop',
          data: const {'count': 3});

      expect(events.map((e) => e.runtimeType), [
        StoryQuestionRepliedEvent,
        StoryCountdownReminderEvent,
        StoryLinkTappedEvent,
        StoryProductTappedEvent,
        StoryCustomInteractionEvent,
      ]);
      expect((events.first as StoryQuestionRepliedEvent).text, 'Hi');
      expect((events[2] as StoryLinkTappedEvent).url.host, 'example.com');
    });

    test('apps can push results with setState', () {
      final controller = create();
      var notified = 0;
      controller.addListener(() => notified++);
      final state =
          StoryChoiceState(selectedChoiceId: 'tea', counts: const {'tea': 10});
      controller.setState('poll', state);
      controller.setState('poll', state); // unchanged: no notification
      expect(notified, 1);
      controller.clearState('poll');
      expect(controller.stateOf<StoryChoiceState>('poll'), isNull);
    });
  });

  test('countdown formatting', () {
    expect(formatStoryCountdown(Duration.zero), 'Ended');
    expect(formatStoryCountdown(const Duration(minutes: 5, seconds: 3)),
        '00:05:03');
    expect(
      formatStoryCountdown(const Duration(days: 2, hours: 3, seconds: 9)),
      '2d 03:00:09',
    );
  });
}
