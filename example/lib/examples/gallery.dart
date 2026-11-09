import 'package:flutter/material.dart';

import '01_basic_story/main.dart' show basicStoryExample;
import '02_images_and_transitions/main.dart' show imagesExample;
import '03_custom_viewer/main.dart' show customViewerExample;
import '04_interactive_stickers/main.dart' show interactiveExample;
import '05_video_and_audio/main.dart' show videoExample;
import '06_story_editor/main.dart' show editorExample;
import '07_save_load_validate/main.dart' show saveLoadExample;
import '08_export/main.dart' show exportExample;
import '09_headless_playback/main.dart' show headlessExample;
import '10_custom_renderer/main.dart' show customRendererExample;
import 'shared.dart';

/// Every example, from basic to advanced.
const List<StoryExample> allExamples = [
  basicStoryExample,
  imagesExample,
  customViewerExample,
  interactiveExample,
  videoExample,
  editorExample,
  saveLoadExample,
  exportExample,
  headlessExample,
  customRendererExample,
];

/// Lists the examples; tapping one opens it.
class ExampleGallery extends StatelessWidget {
  const ExampleGallery({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final example in allExamples)
            ListTile(
              leading: CircleAvatar(child: Text('${example.number}')),
              title: Text(example.title),
              subtitle: Text(
                example.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => openExample(context, example),
            ),
        ],
      );
}
