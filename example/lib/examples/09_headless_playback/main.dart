import 'dart:async';

import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../01_basic_story/main.dart' show basicDocument;
import '../shared.dart';

/// Run: flutter run -t lib/examples/09_headless_playback/main.dart
void main() => runApp(const ExampleApp(example: headlessExample));

const headlessExample = StoryExample(
  number: 9,
  title: 'Headless playback',
  description: 'A completely custom player built on StoryController: its '
      'own progress bar, buttons, and status line, with StoryItemView '
      'drawing the current item. No StoryViewer involved.',
  page: HeadlessPage(),
);

class HeadlessPage extends StatefulWidget {
  const HeadlessPage({super.key});

  @override
  State<HeadlessPage> createState() => _HeadlessPageState();
}

class _HeadlessPageState extends State<HeadlessPage> {
  final StoryController _controller = StoryController(
    document: basicDocument,
    config: const StoryPlaybackConfig(
      defaultItemDuration: Duration(seconds: 4),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.play();
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Custom player')),
        body: ValueListenableBuilder<StoryPlaybackState>(
          valueListenable: _controller.state,
          builder: (context, state, child) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CurrentItem(controller: _controller),
                    ),
                  ),
                ),
              ),
              Text(
                'Item ${state.itemIndex + 1} · ${state.status.name} · '
                '${state.position.inMilliseconds / 1000}s',
              ),
              PlayerButtons(controller: _controller, state: state),
            ],
          ),
        ),
      );
}

/// Draws the controller's current item.
class CurrentItem extends StatelessWidget {
  const CurrentItem({required this.controller, super.key});

  final StoryController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.currentItem;
    if (item == null) return const ColoredBox(color: Colors.black);
    return StoryItemView(document: controller.document, item: item);
  }
}

/// Previous, play/pause, next, and restart.
class PlayerButtons extends StatelessWidget {
  const PlayerButtons({
    required this.controller,
    required this.state,
    super.key,
  });

  final StoryController controller;
  final StoryPlaybackState state;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: controller.previous,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton.filled(
              tooltip: state.isPlaying ? 'Pause' : 'Play',
              iconSize: 36,
              onPressed: state.isPlaying
                  ? controller.pause
                  : () {
                      controller.removePauseReason(StoryPauseReason.user);
                      controller.play();
                    },
              icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: controller.next,
              icon: const Icon(Icons.skip_next),
            ),
            IconButton(
              tooltip: 'Restart',
              onPressed: () => controller
                  .jumpTo(const StoryItemLocation(groupIndex: 0, itemIndex: 0)),
              icon: const Icon(Icons.replay),
            ),
          ],
        ),
      );
}
