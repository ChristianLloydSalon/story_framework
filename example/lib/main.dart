import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import 'sample_stories.dart';

void main() => runApp(const StoryExampleApp());

/// A small app showing a story tray and the full-screen viewer.
class StoryExampleApp extends StatelessWidget {
  const StoryExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Story Framework',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const StoryTrayPage(),
    );
  }
}

/// Lists each story group as a tappable avatar.
class StoryTrayPage extends StatelessWidget {
  const StoryTrayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final document = sampleDocument();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stories'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => StoryEditorPage(initial: document),
              ),
            ),
            icon: const Icon(Icons.edit),
            label: const Text('Create'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: document.groups.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => StoryAvatar(
                document: document,
                groupIndex: index,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tap a story. Tap the right side to go forward, the left side to '
            'go back, hold to pause, swipe sideways to switch people, and '
            'swipe down to close.',
          ),
        ],
      ),
    );
  }
}

/// A circular avatar that opens the viewer at its group.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    required this.document,
    required this.groupIndex,
    super.key,
  });

  final StoryDocument document;
  final int groupIndex;

  @override
  Widget build(BuildContext context) {
    final group = document.groups[groupIndex];
    final title = group.title ?? group.id;
    return Semantics(
      button: true,
      label: 'Open stories from $title',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (context) => StoryViewerPage(
              document: document,
              groupIndex: groupIndex,
            ),
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                title.characters.first,
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}

/// The full-screen viewer, starting at [groupIndex].
class StoryViewerPage extends StatelessWidget {
  const StoryViewerPage({
    required this.document,
    required this.groupIndex,
    super.key,
  });

  final StoryDocument document;
  final int groupIndex;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: StoryViewer(
        document: document,
        initialLocation:
            StoryItemLocation(groupIndex: groupIndex, itemIndex: 0),
        playbackConfig: const StoryPlaybackConfig(
          defaultItemDuration: Duration(seconds: 6),
        ),
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
        ],
        // A real app would send votes to its backend and open links here.
        onInteraction: (event) => debugPrint('Interaction: $event'),
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}

/// A decorative reply bar shown as the viewer footer.
class ReplyBar extends StatelessWidget {
  const ReplyBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white70),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          'Send message',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

/// Shown in the middle of the story while the user holds to pause.
class PausedBadge extends StatelessWidget {
  const PausedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
}

/// The story editor, with a preview button that plays the current draft.
class StoryEditorPage extends StatefulWidget {
  const StoryEditorPage({required this.initial, super.key});

  final StoryDocument initial;

  @override
  State<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends State<StoryEditorPage> {
  StoryDocument? _draft;

  @override
  Widget build(BuildContext context) {
    final draft = _draft ?? widget.initial;
    return Scaffold(
      backgroundColor: StoryEditorColors.background,
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (context) =>
                    StoryViewerPage(document: draft, groupIndex: 0),
              ),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Preview'),
          ),
        ],
      ),
      body: SafeArea(
        child: StoryEditor(
          document: widget.initial,
          // A real app would save the draft here.
          onChanged: (document) => setState(() => _draft = document),
        ),
      ),
    );
  }
}
