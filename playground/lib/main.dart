import 'dart:async';

import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import 'seed_document.dart';

void main() => runApp(const PlaygroundApp());

class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Story Framework Playground',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const PlaygroundPage(),
      );
}

/// The editor and a live preview of the draft, side by side on wide screens
/// and switched with a toggle on narrow ones.
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  /// The width at which the preview moves beside the editor.
  static const double sideBySideWidth = 1100;

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

enum _Pane { edit, preview }

class _PlaygroundPageState extends State<PlaygroundPage> {
  final StoryEditorController _controller =
      StoryEditorController(document: seedDocument());

  /// The document the preview plays. It lags the editor slightly so a drag
  /// does not restart playback on every frame.
  StoryDocument? _previewDocument;
  StoryItemLocation? _previewLocation;
  Timer? _debounce;

  /// Bumped to make the preview start over.
  int _previewRun = 0;
  _Pane _pane = _Pane.edit;

  @override
  void initState() {
    super.initState();
    _syncPreview();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(StoryDocument document) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(_syncPreview);
    });
  }

  /// Copies the editor's document, starting the preview at the item being
  /// edited.
  void _syncPreview() {
    final document = _controller.document;
    _previewDocument = document;
    _previewLocation = _locate(document, _controller.currentItemId);
  }

  static StoryItemLocation? _locate(StoryDocument document, String? itemId) {
    for (var g = 0; g < document.groups.length; g++) {
      final items = document.groups[g].items;
      for (var i = 0; i < items.length; i++) {
        if (items[i].id == itemId) {
          return StoryItemLocation(groupIndex: g, itemIndex: i);
        }
      }
    }
    return null;
  }

  /// Shows the latest draft and plays it from the item being edited.
  void _restart() => setState(() {
        _debounce?.cancel();
        _syncPreview();
        _previewRun++;
      });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= PlaygroundPage.sideBySideWidth;
          final editor = StoryEditor(
            controller: _controller,
            onChanged: _onChanged,
          );
          final preview = PreviewPane(
            key: ValueKey(_previewRun),
            document: _previewDocument,
            location: _previewLocation,
            onRestart: _restart,
          );
          return Scaffold(
            backgroundColor: StoryEditorColors.background,
            appBar: AppBar(
              backgroundColor: StoryEditorColors.background,
              title: const Text('Story Framework Playground'),
              actions: [
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SegmentedButton<_Pane>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _Pane.edit,
                          icon: Icon(Icons.edit),
                          label: Text('Edit'),
                        ),
                        ButtonSegment(
                          value: _Pane.preview,
                          icon: Icon(Icons.play_arrow),
                          label: Text('Preview'),
                        ),
                      ],
                      selected: {_pane},
                      onSelectionChanged: (selection) {
                        _pane = selection.first;
                        _restart();
                      },
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: editor),
                        const VerticalDivider(width: 1),
                        SizedBox(width: 420, child: preview),
                      ],
                    )
                  // The draft lives in the controller, so switching panes
                  // loses nothing.
                  : switch (_pane) {
                      _Pane.edit => editor,
                      _Pane.preview => preview,
                    },
            ),
          );
        },
      );
}

/// Plays the draft inside a phone-shaped frame.
class PreviewPane extends StatelessWidget {
  const PreviewPane({
    required this.document,
    required this.location,
    required this.onRestart,
    super.key,
  });

  final StoryDocument? document;
  final StoryItemLocation? location;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final document = this.document;
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Text(
                  'Live preview',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Restart preview',
                  onPressed: onRestart,
                  icon: const Icon(Icons.replay),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: document == null || document.allItems.isEmpty
                        ? const EmptyPreview()
                        : StoryViewer(
                            document: document,
                            initialLocation: location,
                            // Loop, so the preview keeps playing while editing.
                            onComplete: onRestart,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyPreview extends StatelessWidget {
  const EmptyPreview({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF16161D),
        child: Center(
          child: Text(
            'Add a story to preview it.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
}
