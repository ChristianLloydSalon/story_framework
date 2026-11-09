import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../shared.dart';

/// Run: flutter run -t lib/examples/02_images_and_transitions/main.dart
void main() => runApp(const ExampleApp(example: imagesExample));

const imagesExample = StoryExample(
  number: 2,
  title: 'Images and transitions',
  description: 'Network photos with per-item durations and transitions '
      '(fade, slide, zoom, reveal). Swipe sideways to switch people with '
      'the cube transition. Needs an internet connection.',
  page: ImagesPage(),
);

StoryItem _photo(String id, int picsumId, String transition, int seconds) =>
    StoryItem(
      id: id,
      duration: FixedItemDuration(Duration(seconds: seconds)),
      transition: StoryTransitionConfiguration.preset(transition,
          duration: const Duration(milliseconds: 450)),
      background: gradient(0xFF232526, 0xFF414345),
      elements: [
        ImageElement(
          id: '$id-photo',
          transform: fullCanvas,
          source: NetworkStorySource(
              Uri.parse('https://picsum.photos/id/$picsumId/1080/1920')),
          semanticLabel: 'Photo $picsumId',
        ),
        title('$id-label', transition, y: 1650, size: 80),
      ],
    );

final StoryDocument imagesDocument = StoryDocument(
  id: 'images',
  groups: [
    StoryGroup(id: 'trip', title: 'Trip', items: [
      _photo('mountains', 1018, 'fade', 4),
      _photo('lake', 1015, 'slide', 4),
      _photo('forest', 1043, 'zoom', 4),
    ]),
    StoryGroup(id: 'city', title: 'City', items: [
      _photo('street', 1067, 'reveal', 4),
      _photo('bridge', 1044, 'scale', 4),
    ]),
  ],
);

class ImagesPage extends StatelessWidget {
  const ImagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return StoryPageFrame(
      child: StoryViewer(
        document: imagesDocument,
        config: const StoryViewerConfig(
          groupTransition: StoryTransitionConfiguration.preset('cube',
              duration: Duration(milliseconds: 500)),
        ),
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}
