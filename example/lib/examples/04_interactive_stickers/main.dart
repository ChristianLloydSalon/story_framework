import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../shared.dart';

/// Run: flutter run -t lib/examples/04_interactive_stickers/main.dart
void main() => runApp(const ExampleApp(example: interactiveExample));

const interactiveExample = StoryExample(
  number: 4,
  title: 'Interactive stickers',
  description: 'A poll, a quiz, an emoji slider, a question box, a '
      'countdown, and a link. Each interaction appears in a snackbar, where '
      'a real app would call its backend.',
  page: InteractivePage(),
);

StoryItem _sticker(
  String id,
  int top,
  int bottom,
  String heading,
  StoryInteraction interaction, {
  double height = 560,
}) =>
    StoryItem(
      id: id,
      duration: const FixedItemDuration(Duration(seconds: 10)),
      background: gradient(top, bottom),
      elements: [
        title('$id-title', heading, y: 480, size: 80),
        InteractiveElement(
          id: '$id-sticker',
          transform: box(540, 1050, 880, height),
          interaction: interaction,
        ),
      ],
    );

final StoryDocument interactiveDocument = StoryDocument(
  id: 'interactive',
  groups: [
    StoryGroup(id: 'stickers', title: 'Stickers', items: [
      _sticker(
        'poll',
        0xFFFF512F,
        0xFFDD2476,
        'Poll',
        StoryPoll(question: 'Tabs or spaces?', choices: const [
          StoryChoice(id: 'tabs', label: 'Tabs'),
          StoryChoice(id: 'spaces', label: 'Spaces'),
        ]),
      ),
      _sticker(
        'quiz',
        0xFF4776E6,
        0xFF8E54E9,
        'Quiz',
        StoryQuiz(
          question: 'Which language is Flutter written in?',
          choices: const [
            StoryChoice(id: 'kotlin', label: 'Kotlin'),
            StoryChoice(id: 'dart', label: 'Dart'),
            StoryChoice(id: 'swift', label: 'Swift'),
          ],
          correctChoiceId: 'dart',
        ),
        height: 760,
      ),
      _sticker(
        'slider',
        0xFFF7971E,
        0xFFFFD200,
        'Emoji slider',
        const StorySlider(question: 'How much do you love stories?'),
        height: 420,
      ),
      _sticker(
        'question',
        0xFF11998E,
        0xFF38EF7D,
        'Question box',
        const StoryQuestion(prompt: 'Ask me anything'),
        height: 460,
      ),
      _sticker(
        'countdown',
        0xFF834D9B,
        0xFFD04ED6,
        'Countdown',
        StoryCountdown(
          title: 'Launch day',
          endsAt: DateTime.now().add(const Duration(days: 3)),
        ),
        height: 460,
      ),
      _sticker(
        'link',
        0xFF2193B0,
        0xFF6DD5ED,
        'Link',
        StoryLink(
          url: Uri.parse('https://pub.dev/packages/story_framework'),
          label: 'View the package',
        ),
        height: 160,
      ),
    ]),
  ],
);

/// A short description of what the viewer did.
String describe(StoryInteractionEvent event) => switch (event) {
      StoryChoiceSelectedEvent(:final choiceId, isCorrect: true) =>
        'Chose $choiceId (correct)',
      StoryChoiceSelectedEvent(:final choiceId, isCorrect: false) =>
        'Chose $choiceId (wrong)',
      StoryChoiceSelectedEvent(:final choiceId) => 'Voted for $choiceId',
      StorySliderSubmittedEvent(:final value) =>
        'Slider: ${(value * 100).round()}%',
      StoryQuestionRepliedEvent(:final text) => 'Reply: $text',
      StoryCountdownReminderEvent(:final reminderSet) =>
        reminderSet ? 'Reminder set' : 'Reminder removed',
      StoryLinkTappedEvent(:final url) => 'Open $url',
      StoryProductTappedEvent() => 'Product tapped',
      StoryCustomInteractionEvent() => 'Custom interaction',
    };

class InteractivePage extends StatelessWidget {
  const InteractivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return StoryPageFrame(
      child: StoryViewer(
        document: interactiveDocument,
        onInteraction: (event) => messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(describe(event)))),
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}
