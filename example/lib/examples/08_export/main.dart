import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../04_interactive_stickers/main.dart' show interactiveDocument;
import '../shared.dart';

/// Run: flutter run -t lib/examples/08_export/main.dart
void main() => runApp(const ExampleApp(example: exportExample));

const exportExample = StoryExample(
  number: 8,
  title: 'Export',
  description: 'Renders every item to a PNG offscreen, with the same '
      'renderers as the viewer, and exports the document as JSON. Shows '
      'progress and supports cancelling. Video export works the same way '
      'with an encoder you provide.',
  page: ExportPage(),
);

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final StoryExporterRegistry _exporters = StoryExporterRegistry([
    const StoryDocumentExporter(),
    StoryPngExporter(),
  ]);

  StoryExportJob? _job;
  List<StoryExportOutput> _outputs = const [];
  String? _message;

  Future<void> _export(StoryExportFormat format) async {
    final job = _exporters.export(
      interactiveDocument,
      StoryExportConfig(format: format, width: 360),
    );
    setState(() {
      _job = job;
      _outputs = const [];
      _message = null;
    });
    try {
      final result = await job.result;
      if (!mounted) return;
      setState(() {
        _outputs = result.outputs;
        _message = 'Exported ${result.outputs.length} file(s)';
      });
    } on StoryCancelledException {
      if (mounted) setState(() => _message = 'Cancelled');
    } on ExportException catch (error) {
      if (mounted) setState(() => _message = 'Failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _job = null);
    }
  }

  @override
  void dispose() {
    _job?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final message = _message;
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed:
                    job == null ? () => _export(StoryExportFormat.png) : null,
                icon: const Icon(Icons.image),
                label: const Text('Export PNGs'),
              ),
              OutlinedButton.icon(
                onPressed: job == null
                    ? () => _export(StoryExportFormat.document)
                    : null,
                icon: const Icon(Icons.data_object),
                label: const Text('Export JSON'),
              ),
              if (job != null)
                TextButton(onPressed: job.cancel, child: const Text('Cancel')),
            ],
          ),
          const SizedBox(height: 16),
          if (job != null)
            ValueListenableBuilder<double>(
              valueListenable: job.progress,
              builder: (context, value, child) =>
                  LinearProgressIndicator(value: value),
            ),
          if (message != null) Text(message),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final output in _outputs) ExportedFile(output: output),
            ],
          ),
        ],
      ),
    );
  }
}

/// A PNG thumbnail, or the size of any other file.
class ExportedFile extends StatelessWidget {
  const ExportedFile({required this.output, super.key});

  final StoryExportOutput output;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (output.mimeType == 'image/png')
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(output.bytes, width: 120),
            )
          else
            const Icon(Icons.description, size: 64),
          const SizedBox(height: 4),
          Text(output.name),
          Text('${(output.bytes.length / 1024).toStringAsFixed(1)} KB',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
