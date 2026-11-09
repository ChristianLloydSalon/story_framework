import 'package:story_framework/editor.dart';

StoryTransform boxAt(double x, double y, [double w = 100, double h = 100]) =>
    StoryTransform(position: StoryPoint(x, y), size: StorySize(w, h));

TextElement textAt(String id, double x, double y,
        {bool locked = false, bool visible = true, int zIndex = 0}) =>
    TextElement(
      id: id,
      transform: boxAt(x, y, 200),
      text: id,
      locked: locked,
      visible: visible,
      zIndex: zIndex,
    );

/// Two groups: g1 has items a (with elements) and b; g2 has c.
StoryDocument editorDoc({List<StoryElement>? elements}) => StoryDocument(
      id: 'doc',
      groups: [
        StoryGroup(id: 'g1', title: 'One', items: [
          StoryItem(
            id: 'a',
            duration: const FixedItemDuration(Duration(seconds: 5)),
            elements: elements ??
                [
                  textAt('t1', 200, 200),
                  textAt('t2', 600, 600),
                  textAt('t3', 900, 1500),
                ],
          ),
          StoryItem(id: 'b'),
        ]),
        StoryGroup(id: 'g2', items: [StoryItem(id: 'c')]),
      ],
    );

StoryEditorController editorFor(
  StoryDocument document, {
  StoryEditorConfig config = const StoryEditorConfig(),
  void Function(StoryDocument)? onChanged,
}) =>
    StoryEditorController(
      document: document,
      config: config,
      idGenerator: SequentialStoryIdGenerator(),
      onDocumentChanged: onChanged,
    );
