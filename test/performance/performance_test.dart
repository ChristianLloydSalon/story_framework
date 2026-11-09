import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/story_framework.dart';

import '../helpers/engine_fakes.dart';

/// Engineering budgets, not device benchmarks. They catch regressions such as
/// quadratic work or whole-tree rebuilds; profile real devices with DevTools.
StoryDocument largeDocument({int items = 50, int elementsPerItem = 60}) =>
    StoryDocument(id: 'large', groups: [
      StoryGroup(id: 'g', items: [
        for (var i = 0; i < items; i++)
          StoryItem(
            id: 'item-$i',
            duration: const FixedItemDuration(Duration(seconds: 5)),
            elements: [
              for (var e = 0; e < elementsPerItem; e++)
                e.isEven
                    ? TextElement(
                        id: 'text-$e',
                        transform: StoryTransform(
                          position: StoryPoint(20.0 * (e % 50), 30.0 * e),
                          size: const StorySize(200, 60),
                        ),
                        text: 'Label $e',
                      )
                    : ShapeElement(
                        id: 'shape-$e',
                        transform: StoryTransform(
                          position: StoryPoint(15.0 * e, 25.0 * (e % 70)),
                          size: const StorySize(80, 80),
                        ),
                        shape: StoryShapeType.ellipse,
                        fillColor: StoryColor.white,
                      ),
            ],
          ),
      ]),
    ]);

void main() {
  test('large documents serialize and validate quickly', () {
    final document = largeDocument();
    const codec = StoryDocumentCodec();
    final watch = Stopwatch()..start();
    final json = codec.encodeToString(document);
    final restored = codec.decodeFromString(json);
    final valid = const StoryDocumentValidator().validate(restored).isValid;
    watch.stop();
    expect(valid, isTrue);
    expect(restored.allItems.length, 50);
    expect(watch.elapsedMilliseconds, lessThan(2000),
        reason: '3000 elements round-trip and validate');
  });

  test('edit history stays bounded and edits share structure', () {
    final editor = StoryEditorController(
      document: largeDocument(items: 10),
      config: const StoryEditorConfig(
          historyLimit: 50, validation: StoryEditValidation.none),
      idGenerator: SequentialStoryIdGenerator(),
    );
    final before = editor.document;
    editor.select(['text-0']);
    final watch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      editor.nudgeSelection(1, 0);
    }
    watch.stop();
    var undoSteps = 0;
    while (editor.canUndo) {
      editor.undo();
      undoSteps++;
    }
    expect(undoSteps, 50, reason: 'history limit bounds memory');
    expect(
        identical(editor.document.groups.single.items[5],
            before.groups.single.items[5]),
        isTrue,
        reason: 'untouched items are shared, not copied');
    expect(watch.elapsedMilliseconds, lessThan(3000));
    editor.dispose();
  });

  testWidgets('a 300-element item renders and progress does not rebuild it',
      (tester) async {
    final harness = EngineHarness();
    final controller = StoryController(
      document: largeDocument(items: 2, elementsPerItem: 300),
      clock: harness.clock,
      tickerFactory: harness.createTicker,
    );
    addTearDown(controller.dispose);
    var builds = 0;
    final registry = StoryRendererRegistry.withDefaults([
      _CountingTextRenderer(() => builds++),
    ]);
    addTearDown(registry.dispose);

    final watch = Stopwatch()..start();
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child:
            StoryViewer.controller(controller: controller, registry: registry),
      ),
    ));
    await tester.pump();
    watch.stop();
    expect(builds, 150, reason: 'each text element built once');
    expect(watch.elapsedMilliseconds, lessThan(5000));

    for (var i = 0; i < 60; i++) {
      harness.advance(const Duration(milliseconds: 16));
      await tester.pump();
    }
    expect(builds, 150, reason: 'a second of progress rebuilt nothing');
  });
}

final class _CountingTextRenderer extends StoryElementRenderer<TextElement> {
  _CountingTextRenderer(this.onBuild);

  final VoidCallback onBuild;

  @override
  String get id => 'counting-text';

  @override
  Widget buildElement(BuildContext context, TextElement element,
      StoryRenderContext renderContext) {
    onBuild();
    return const SizedBox.expand();
  }
}
