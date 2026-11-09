import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../01_basic_story/main.dart' show basicDocument;
import '../shared.dart';

/// Run: flutter run -t lib/examples/03_custom_viewer/main.dart
void main() => runApp(const ExampleApp(example: customViewerExample));

const customViewerExample = StoryExample(
  number: 3,
  title: 'Customized viewer',
  description: 'A custom header with the item count, a reply bar footer, a '
      '"Paused" badge overlay, and a speed button overlay. Hold the story '
      'to see the badge; tap the speed chip to play faster.',
  page: CustomViewerPage(),
);

class CustomViewerPage extends StatelessWidget {
  const CustomViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return StoryPageFrame(
      child: StoryViewer(
        document: basicDocument,
        config: const StoryViewerConfig(previousTapFraction: 0.25),
        playbackConfig: const StoryPlaybackConfig(
          defaultItemDuration: Duration(seconds: 6),
        ),
        headerBuilder: (context, controller) =>
            CustomHeader(controller: controller, onClose: navigator.pop),
        footerBuilder: (context, controller) => const ReplyBar(),
        overlays: [
          StoryOverlay(
            id: 'paused',
            alignment: AlignmentDirectional.center,
            interactive: false,
            visibleWhen: (state) =>
                state.pauseReasons.contains(StoryPauseReason.user),
            builder: (context, controller) => const PausedBadge(),
          ),
          StoryOverlay(
            id: 'speed',
            alignment: AlignmentDirectional.bottomEnd,
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 80),
            builder: (context, controller) =>
                SpeedButton(controller: controller),
          ),
        ],
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}

/// Avatar, name, "2 / 3", and a close button.
class CustomHeader extends StatelessWidget {
  const CustomHeader({
    required this.controller,
    required this.onClose,
    super.key,
  });

  final StoryController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<StoryPlaybackState>(
        valueListenable: controller.state,
        builder: (context, state, child) {
          final group = controller.document.groups[state.groupIndex];
          final name = group.title ?? group.id;
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 4, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(name.characters.first,
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${state.itemIndex + 1} / ${group.items.length}',
                    style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          );
        },
      );
}

/// Cycles playback speed between 1×, 1.5×, and 2×.
class SpeedButton extends StatelessWidget {
  const SpeedButton({required this.controller, super.key});

  final StoryController controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<StoryPlaybackState>(
        valueListenable: controller.state,
        builder: (context, state, child) {
          final speed = state.playbackSpeed;
          final next = speed >= 2 ? 1.0 : speed + 0.5;
          return ActionChip(
            backgroundColor: Colors.black54,
            label: Text('$speed×', style: const TextStyle(color: Colors.white)),
            onPressed: () => controller.setPlaybackSpeed(next),
          );
        },
      );
}

/// A decorative reply field.
class ReplyBar extends StatelessWidget {
  const ReplyBar({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Text('Send message',
              style: TextStyle(color: Colors.white70)),
        ),
      );
}

/// Shown while the user holds the story.
class PausedBadge extends StatelessWidget {
  const PausedBadge({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text('Paused', style: TextStyle(color: Colors.white)),
        ),
      );
}
