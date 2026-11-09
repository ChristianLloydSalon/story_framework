import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../01_basic_story/main.dart' show basicDocument;
import '../shared.dart';

/// Run: flutter run -t lib/examples/06_story_editor/main.dart
void main() => runApp(const ExampleApp(example: editorExample));

const editorExample = StoryExample(
  number: 6,
  title: 'Story editor',
  description: 'The complete editor: add text, stickers, shapes, and '
      'drawings; move, scale, rotate, and snap them; reorder layers and '
      'stories; undo and redo. Preview plays the current draft. Wider '
      'screens (tablet, desktop, web) show every panel at once.',
  page: EditorPage(),
);

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  StoryDocument _draft = basicDocument;

  void _preview() {
    final draft = _draft;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => PreviewPage(document: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: StoryEditorColors.background,
        appBar: AppBar(
          title: const Text('Editor'),
          actions: [
            TextButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Preview'),
            ),
          ],
        ),
        body: SafeArea(
          child: StoryEditor(
            document: basicDocument,
            // A real app would save the draft here.
            onChanged: (document) => setState(() => _draft = document),
          ),
        ),
      );
}

/// Plays a document full screen.
class PreviewPage extends StatelessWidget {
  const PreviewPage({required this.document, super.key});

  final StoryDocument document;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return StoryPageFrame(
      child: StoryViewer(
        document: document,
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}
