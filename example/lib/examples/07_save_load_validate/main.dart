import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../01_basic_story/main.dart' show basicDocument;
import '../06_story_editor/main.dart' show PreviewPage;
import '../shared.dart';

/// Run: flutter run -t lib/examples/07_save_load_validate/main.dart
void main() => runApp(const ExampleApp(example: saveLoadExample));

const saveLoadExample = StoryExample(
  number: 7,
  title: 'Save, load, and validate',
  description: 'Encodes a story to versioned JSON, decodes it back, checks '
      'that nothing changed, and plays the restored copy. Switch to the '
      'broken document to see validation issues.',
  page: SaveLoadPage(),
);

/// Invalid on purpose: documents need an id.
final StoryDocument brokenDocument =
    StoryDocument(id: '', groups: basicDocument.groups);

class SaveLoadPage extends StatefulWidget {
  const SaveLoadPage({super.key});

  @override
  State<SaveLoadPage> createState() => _SaveLoadPageState();
}

class _SaveLoadPageState extends State<SaveLoadPage> {
  static const StoryDocumentCodec _codec = StoryDocumentCodec();
  bool _broken = false;

  StoryDocument get _document => _broken ? brokenDocument : basicDocument;

  void _play(StoryDocument document) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => PreviewPage(document: document),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final json = _codec.encodeToString(document, pretty: true);
    final restored = _codec.decodeFromString(json);
    final report = const StoryDocumentValidator().validate(restored);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Save, load, and validate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Use a broken document'),
            value: _broken,
            onChanged: (value) => setState(() => _broken = value),
          ),
          ListTile(
            leading: Icon(
              restored == document ? Icons.check_circle : Icons.error,
              color: restored == document ? Colors.green : Colors.red,
            ),
            title: Text(restored == document
                ? 'Round trip is lossless'
                : 'Round trip changed the document'),
            subtitle: Text('${json.length} characters of JSON'),
          ),
          ListTile(
            leading: Icon(
              report.isValid ? Icons.verified : Icons.report,
              color: report.isValid ? Colors.green : Colors.orange,
            ),
            title: Text(report.isValid
                ? 'Valid'
                : '${report.errors.length} error(s), '
                    '${report.warnings.length} warning(s)'),
          ),
          for (final issue in report.issues)
            ListTile(
              dense: true,
              title: Text('${issue.code}: ${issue.message}'),
              subtitle: Text('${issue.severity.name} at ${issue.path}'),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: report.isValid ? () => _play(restored) : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play the restored copy'),
          ),
          const SizedBox(height: 16),
          Text('JSON', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
