import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../shared.dart';

/// Run: flutter run -t lib/examples/01_basic_story/main.dart
void main() => runApp(const ExampleApp(example: basicStoryExample));

const basicStoryExample = StoryExample(
  number: 1,
  title: 'Basic story',
  description: 'The smallest viewer: a document with three text items. '
      'Tap right to go forward, left to go back, hold to pause, and swipe '
      'down to close.',
  page: BasicStoryPage(),
);

final StoryDocument basicDocument = StoryDocument(
  id: 'basic',
  groups: [
    StoryGroup(id: 'ada', title: 'Ada', items: [
      StoryItem(
        id: 'hello',
        background: gradient(0xFF6A11CB, 0xFF2575FC),
        elements: [title('t', 'Hello,\nstories!', size: 130)],
      ),
      StoryItem(
        id: 'tap',
        background: gradient(0xFFFF512F, 0xFFDD2476),
        elements: [title('t', 'Tap the right side\nto continue', size: 88)],
      ),
      StoryItem(
        id: 'hold',
        background: gradient(0xFF11998E, 0xFF38EF7D),
        elements: [title('t', 'Hold to pause', size: 96)],
      ),
    ]),
  ],
);

class BasicStoryPage extends StatelessWidget {
  const BasicStoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return StoryPageFrame(
      child: StoryViewer(
        document: basicDocument,
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}
