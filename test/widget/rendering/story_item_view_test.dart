import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/rendering.dart';

/// A valid 1×1 transparent PNG.
final transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

StoryTransform at(double x, double y, [double w = 100, double h = 100]) =>
    StoryTransform(position: StoryPoint(x, y), size: StorySize(w, h));

StoryDocument docWith(List<StoryElement> elements,
        {StoryBackground? background, List<StoryAsset> assets = const []}) =>
    StoryDocument(
      id: 'd',
      assets: assets,
      groups: [
        StoryGroup(id: 'g', items: [
          StoryItem(id: 'i', elements: elements, background: background),
        ]),
      ],
    );

/// Hosts a view in a 270×480 box (a quarter of the 1080×1920 canvas),
/// centered in the 800×600 test surface.
class _Host extends StatelessWidget {
  const _Host({required this.child, this.textScaler = TextScaler.noScaling});

  final Widget child;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 270, height: 480, child: child)),
        ),
      );
}

void main() {
  final errors = <(StoryElement, Object)>[];
  final options = StoryRenderOptions(
    onError: (element, error, _) => errors.add((element, error)),
    loadingBuilder: (context, element) => const Text('loading'),
    errorBuilder: (context, element, error) => const Text('failed'),
    unsupportedBuilder: (context, element) =>
        Text('unsupported ${element.type}'),
  );

  setUp(errors.clear);

  Future<void> pumpDoc(
    WidgetTester tester,
    StoryDocument document, {
    StoryRendererRegistry? registry,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(_Host(
      textScaler: textScaler,
      child: StoryItemView(
        document: document,
        item: document.groups.single.items.single,
        registry: registry,
        options: options,
      ),
    ));
  }

  testWidgets('positions elements by center in scaled canvas units',
      (tester) async {
    await pumpDoc(
        tester,
        docWith([
          TextElement(id: 't', transform: at(540, 300, 200), text: 'Hello'),
        ]));
    expect(find.text('Hello'), findsOneWidget);
    // Host origin is (265, 60); canvas scale is 0.25.
    expect(
      tester.getRect(find.byKey(const ValueKey('t'))),
      const Rect.fromLTWH(375, 122.5, 50, 25),
    );
  });

  testWidgets('falls back to the canvas aspect ratio when unbounded',
      (tester) async {
    final document = docWith([]);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 270,
          child: Column(children: [
            StoryItemView(
                document: document, item: document.groups.single.items.single),
          ]),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(StoryItemView)), const Size(270, 480));
  });

  testWidgets('paints in z-order and skips hidden elements', (tester) async {
    await pumpDoc(
        tester,
        docWith([
          TextElement(id: 'top', transform: at(0, 0), text: 'a', zIndex: 2),
          TextElement(
              id: 'hidden', transform: at(0, 0), text: 'b', visible: false),
          TextElement(id: 'bottom', transform: at(0, 0), text: 'c'),
        ]));
    final order = tester
        .widgetList<StoryElementView>(find.byType(StoryElementView))
        .map((view) => view.renderContext.element.id);
    expect(order, ['bottom', 'top']);
    expect(find.byKey(const ValueKey('hidden')), findsNothing);
  });

  testWidgets('applies opacity, rotation, and semantics labels',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDoc(
        tester,
        docWith([
          TextElement(
            id: 't',
            transform: const StoryTransform(
              position: StoryPoint(540, 960),
              size: StorySize(400, 200),
              rotation: 0.5,
              flipHorizontal: true,
            ),
            text: 'Hi',
            opacity: 0.4,
            semanticLabel: 'Greeting',
          ),
        ]));
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0.4);
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('t')),
          matching: find.byType(Transform)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Greeting'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('text ignores platform text scaling by default', (tester) async {
    await pumpDoc(
      tester,
      docWith([TextElement(id: 't', transform: at(100, 100), text: 'Big')]),
      textScaler: const TextScaler.linear(3),
    );
    expect(
        tester.widget<Text>(find.text('Big')).textScaler, TextScaler.noScaling);
  });

  testWidgets('text outlines render a stroke layer behind the fill',
      (tester) async {
    await pumpDoc(
        tester,
        docWith([
          TextElement(
            id: 't',
            transform: at(100, 100),
            text: 'Outlined',
            style: StoryTextStyle(
                stroke: const StoryStroke(color: StoryColor.black, width: 3)),
          ),
        ]));
    final layers = tester.widgetList<Text>(find.text('Outlined')).toList();
    expect(layers, hasLength(2));
    expect(layers.first.style?.foreground?.style, PaintingStyle.stroke);
    expect(layers.last.style?.foreground, isNull);
  });

  testWidgets('unsupported elements use the fallback and are reported once',
      (tester) async {
    final document = docWith([
      WidgetElement(id: 'w', transform: at(10, 10), widgetType: 'poll'),
    ]);
    await pumpDoc(tester, document);
    await tester.pump();
    expect(find.text('unsupported widget'), findsOneWidget);
    expect(errors.single.$2, isA<RendererNotRegisteredException>());

    await pumpDoc(tester, document); // rebuild
    await tester.pump();
    expect(errors, hasLength(1));
  });

  testWidgets('views rebuild when the registry changes', (tester) async {
    final registry = StoryRendererRegistry.withDefaults();
    addTearDown(registry.dispose);
    await pumpDoc(
      tester,
      docWith([
        WidgetElement(
            id: 'w',
            transform: at(10, 10),
            widgetType: 'poll',
            data: const {
              'question': 'Tea?',
            }),
      ]),
      registry: registry,
    );
    expect(find.text('unsupported widget'), findsOneWidget);

    registry.register(StoryWidgetElementRenderer({
      'poll': (context, element, _) => Text('${element.data['question']}'),
    }));
    await tester.pump();
    expect(find.text('Tea?'), findsOneWidget);
  });

  testWidgets('custom element renderers receive the render context',
      (tester) async {
    final registry = StoryRendererRegistry.withDefaults([
      StoryCustomElementRenderer(
        customType: 'badge',
        builder: (context, element, renderContext) =>
            Text('${element.data['label']} in ${renderContext.item.id} '
                '(${renderContext.mode.name})'),
      ),
    ]);
    addTearDown(registry.dispose);
    await pumpDoc(
      tester,
      docWith([
        CustomElement(
          id: 'c',
          transform: at(500, 500, 400),
          customType: 'badge',
          data: const {'label': 'New'},
        ),
      ]),
      registry: registry,
    );
    expect(find.text('New in i (viewer)'), findsOneWidget);
  });

  testWidgets('unknown elements from newer documents are skipped safely',
      (tester) async {
    await pumpDoc(
        tester,
        docWith([
          UnknownElement(
            id: 'u',
            transform: at(10, 10),
            originalType: 'lottie',
            rawJson: const {'src': 'a.json'},
          ),
          TextElement(id: 't', transform: at(100, 100), text: 'still here'),
        ]));
    await tester.pump();
    expect(find.text('still here'), findsOneWidget);
    expect(find.text('unsupported lottie'), findsOneWidget);
    expect(errors.single.$1.id, 'u');
  });

  group('images', () {
    testWidgets('show loading until decoded, then the image', (tester) async {
      await pumpDoc(
          tester,
          docWith([
            ImageElement(
              id: 'img',
              transform: at(540, 960, 1080, 1920),
              source: MemoryStorySource(transparentPng),
            ),
          ]));
      expect(find.text('loading'), findsOneWidget);

      await tester.runAsync(() => precacheImage(
            MemoryImage(transparentPng),
            tester.element(find.byType(StoryItemView)),
          ));
      await tester.pumpAndSettle();
      expect(find.text('loading'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(errors, isEmpty);
    });

    testWidgets('unloadable sources show the error state and report it',
        (tester) async {
      await pumpDoc(
          tester,
          docWith([
            ImageElement(
              id: 'stream',
              transform: at(100, 100),
              source: StreamStorySource(() => const Stream.empty()),
            ),
            ImageElement(
              id: 'missing',
              transform: at(300, 300),
              source: const ReferenceStorySource('nope'),
            ),
          ]));
      await tester.pump();
      expect(find.text('failed'), findsNWidgets(2));
      expect(errors.map((e) => e.$2.runtimeType), [
        UnsupportedStoryTypeException,
        StoryNotFoundException,
      ]);
    });

    testWidgets('asset references resolve through the document',
        (tester) async {
      await pumpDoc(
        tester,
        docWith(
          [
            ImageElement(
              id: 'img',
              transform: at(100, 100),
              source: const ReferenceStorySource('hero'),
            ),
          ],
          assets: [
            StoryAsset(
              id: 'hero',
              type: StoryAssetType.image,
              source: MemoryStorySource(transparentPng),
            ),
          ],
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
    });
  });

  group('backgrounds', () {
    testWidgets('item background overrides the canvas background',
        (tester) async {
      await pumpDoc(
        tester,
        docWith([],
            background: const StoryColorBackground(StoryColor(0xFF336699))),
      );
      final box = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(StoryBackgroundView),
          matching: find.byType(ColoredBox)));
      expect(box.color, const Color(0xFF336699));
    });

    testWidgets('gradients become a LinearGradient', (tester) async {
      await pumpDoc(
        tester,
        docWith([],
            background: StoryGradientBackground(
                colors: const [StoryColor.black, StoryColor.white])),
      );
      final decorated = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(StoryBackgroundView),
          matching: find.byType(DecoratedBox)));
      final gradient =
          (decorated.decoration as BoxDecoration).gradient as LinearGradient;
      expect(
          gradient.colors, [const Color(0xFF000000), const Color(0xFFFFFFFF)]);
      expect(gradient.begin, Alignment.topCenter);
    });
  });

  testWidgets('every built-in renderer builds without errors', (tester) async {
    await pumpDoc(
        tester,
        docWith([
          StickerElement(
              id: 'emoji',
              transform: at(100, 100),
              sticker: const EmojiSticker('🎉')),
          StickerElement(
            id: 'img-sticker',
            transform: at(200, 200),
            sticker: ImageSticker(MemoryStorySource(transparentPng)),
          ),
          ShapeElement(
              id: 'shape',
              transform: at(300, 300),
              shape: StoryShapeType.triangle,
              fillColor: StoryColor.white),
          DrawingElement(
            id: 'draw',
            transform: at(400, 400),
            strokes: [
              StoryDrawingStroke(
                  points: const [StoryPoint(0, 0), StoryPoint(90, 90)]),
            ],
          ),
          AudioElement(id: 'audio', source: const FileStorySource('/a.mp3')),
        ]));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(errors, isEmpty);
    expect(find.text('🎉'), findsOneWidget);
  });
}
