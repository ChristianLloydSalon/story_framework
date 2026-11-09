import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/rendering.dart';

StoryTransform get box => const StoryTransform(
    position: StoryPoint(50, 50), size: StorySize(100, 100));

final class _Renderer extends StoryElementRenderer<StoryElement> {
  _Renderer(this.id, {this.accepts});

  @override
  final String id;
  final bool Function(StoryElement element)? accepts;
  int disposals = 0;

  @override
  bool supports(StoryElement element) => accepts?.call(element) ?? true;

  @override
  Widget buildElement(BuildContext context, StoryElement element,
          StoryRenderContext renderContext) =>
      const SizedBox();

  @override
  void dispose() => disposals++;
}

void main() {
  final image = ImageElement(
      id: 'i', transform: box, source: const FileStorySource('/a.png'));
  final text = TextElement(id: 't', transform: box, text: 'hi');

  group('StoryRendererRegistry', () {
    test('defaults cover the built-in visual element types', () {
      final registry = StoryRendererRegistry.withDefaults();
      expect(registry.ids, [
        'image',
        'video',
        'text',
        'sticker',
        'shape',
        'drawing',
        'audio',
        'interactive',
      ]);
      expect(registry.rendererFor(image), isA<StoryImageRenderer>());
      expect(registry.rendererFor(text), isA<StoryTextRenderer>());
      expect(
        registry.rendererFor(
            AudioElement(id: 'a', source: const FileStorySource('/a.mp3'))),
        isA<StoryAudioRenderer>(),
      );
      expect(
        registry.rendererFor(
            WidgetElement(id: 'w', transform: box, widgetType: 'poll')),
        isNull,
        reason: 'widget elements need app builders',
      );
      registry.dispose();
    });

    test('rejects duplicate ids and requires explicit replacement', () {
      final registry = StoryRendererRegistry([_Renderer('a')]);
      expect(() => registry.register(_Renderer('a')),
          throwsA(isA<ConfigurationException>()));
      expect(() => registry.replace(_Renderer('missing')),
          throwsA(isA<ConfigurationException>()));
      registry.dispose();
    });

    test('newest matching renderer wins', () {
      final generic = _Renderer('generic');
      final textOnly = _Renderer('text-only', accepts: (e) => e is TextElement);
      final registry = StoryRendererRegistry([generic, textOnly]);
      expect(registry.rendererFor(text), same(textOnly));
      expect(registry.rendererFor(image), same(generic));
      registry.dispose();
    });

    test('replace keeps priority and disposes the old renderer', () {
      final old = _Renderer('a');
      final later = _Renderer('b');
      final registry = StoryRendererRegistry([old, later]);
      final replacement = _Renderer('a');
      registry.replace(replacement);
      expect(old.disposals, 1);
      expect(registry.ids, ['a', 'b']);
      expect(registry.rendererFor(text), same(later));
      registry.dispose();
      expect(replacement.disposals, 1);
      expect(later.disposals, 1);
    });

    test('unregister hands ownership back without disposing', () {
      final renderer = _Renderer('a');
      final registry = StoryRendererRegistry([renderer]);
      expect(registry.unregister('a'), same(renderer));
      expect(registry.unregister('a'), isNull);
      registry.dispose();
      expect(renderer.disposals, 0);
    });

    test('requireRendererFor throws a typed error', () {
      final registry = StoryRendererRegistry();
      expect(
        () => registry.requireRendererFor(text),
        throwsA(isA<RendererNotRegisteredException>()
            .having((e) => e.elementType, 'elementType', 'text')),
      );
      registry.dispose();
    });

    test('notifies listeners on change and rejects use after dispose', () {
      final registry = StoryRendererRegistry();
      var notified = 0;
      registry.addListener(() => notified++);
      registry.register(_Renderer('a'));
      registry.unregister('a');
      expect(notified, 2);
      registry.dispose();
      expect(() => registry.register(_Renderer('b')),
          throwsA(isA<ControllerDisposedException>()));
    });

    test('app renderers match by widget type and custom type', () {
      final widgets = StoryWidgetElementRenderer(
          {'poll': (context, element, _) => const SizedBox()});
      expect(
        widgets.supports(
            WidgetElement(id: 'w', transform: box, widgetType: 'poll')),
        isTrue,
      );
      expect(
        widgets.supports(
            WidgetElement(id: 'w', transform: box, widgetType: 'quiz')),
        isFalse,
      );
      final custom = StoryCustomElementRenderer(
        customType: 'map',
        builder: (context, element, _) => const SizedBox(),
      );
      expect(custom.id, 'custom:map');
      expect(
        custom.supports(
            CustomElement(id: 'c', transform: box, customType: 'map')),
        isTrue,
      );
      expect(custom.supports(text), isFalse);
    });

    test('custom stickers are supported only with a builder', () {
      final sticker = StickerElement(
        id: 's',
        transform: box,
        sticker: CustomSticker(providerId: 'giphy', stickerId: 'x'),
      );
      expect(const StoryStickerRenderer().supports(sticker), isFalse);
      expect(
        StoryStickerRenderer(customBuilders: {
          'giphy': (context, sticker, element, _) => const SizedBox(),
        }).supports(sticker),
        isTrue,
      );
    });
  });

  group('DefaultStoryImageResolver', () {
    test('maps each source kind to a provider', () {
      final resolver = DefaultStoryImageResolver(
        headersFor: (url) => {'Authorization': 'Bearer t'},
        customResolvers: {
          'cdn': (source) => NetworkImage('https://cdn/${source.data['id']}'),
        },
      );
      final network =
          resolver.resolve(NetworkStorySource(Uri.parse('https://e.com/a.png')))
              as NetworkImage;
      expect(network.url, 'https://e.com/a.png');
      expect(network.headers, {'Authorization': 'Bearer t'});
      expect(
          resolver.resolve(const FileStorySource('/a.png')), isA<FileImage>());
      final asset =
          resolver.resolve(const AssetStorySource('img/a.png', package: 'pkg'))
              as AssetImage;
      expect(asset.keyName, 'packages/pkg/img/a.png');
      expect(resolver.resolve(MemoryStorySource(Uint8List(4))),
          isA<MemoryImage>());
      expect(
        (resolver.resolve(CustomStorySource('cdn', data: const {'id': 7}))
                as NetworkImage)
            .url,
        'https://cdn/7',
      );
      expect(resolver.resolve(CustomStorySource('other')), isNull);
      expect(
        resolver.resolve(StreamStorySource(() => const Stream.empty())),
        isNull,
      );
      expect(resolver.resolve(const ReferenceStorySource('x')), isNull);
    });
  });

  group('conversions', () {
    test('colors, fits, and alignment', () {
      expect(const StoryColor(0x80112233).toColor(), const Color(0x80112233));
      expect(StoryFit.cover.toBoxFit(), BoxFit.cover);
      expect(StoryScalingBehavior.fill.toBoxFit(), BoxFit.fill);
      expect(StoryTextAlign.right.toTextAlign(), TextAlign.right);
      expect(const StoryPoint(-1, 1).toAlignment(), Alignment.bottomLeft);
      expect(const StoryInsets.only(left: 1, bottom: 4).toEdgeInsets(),
          const EdgeInsets.fromLTRB(1, 0, 0, 4));
    });

    test('text styles round font weights and keep shadows', () {
      final style = StoryTextStyle(
        fontSize: 30,
        fontWeight: 640,
        italic: true,
        shadows: const [StoryShadow(blurRadius: 3)],
      ).toTextStyle();
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.shadows, hasLength(1));
      expect(StoryTextStyle(fontWeight: 1200).toTextStyle().fontWeight,
          FontWeight.w900);
      expect(StoryTextStyle(fontWeight: 10).toTextStyle().fontWeight,
          FontWeight.w100);

      final stroked = StoryTextStyle().toTextStyle(
          foreground: Paint()..color = const Color(0xFF000000),
          includeShadows: false);
      expect(stroked.color, isNull);
      expect(stroked.shadows, isEmpty);
    });
  });

  group('painters', () {
    void paint(CustomPainter painter) {
      final recorder = ui.PictureRecorder();
      painter.paint(ui.Canvas(recorder), const Size(100, 100));
      recorder.endRecording().dispose();
    }

    test('every shape paints', () {
      for (final shape in StoryShapeType.values) {
        paint(StoryShapePainter(
          shape: shape,
          fillColor: StoryColor.white,
          stroke: const StoryStroke(color: StoryColor.black, width: 2),
          cornerRadius: 4,
        ));
      }
    });

    test('drawings paint every tool, including single-point strokes', () {
      paint(StoryDrawingPainter([
        for (final tool in StoryDrawingTool.values)
          StoryDrawingStroke(
            tool: tool,
            points: const [StoryPoint(1, 1), StoryPoint(50, 50)],
          ),
        StoryDrawingStroke(points: const [StoryPoint(5, 5)]),
        StoryDrawingStroke(points: const []),
      ]));
    });

    test('repaint only when content changes', () {
      final strokes = [
        StoryDrawingStroke(points: const [StoryPoint(1, 1)])
      ];
      expect(
        StoryDrawingPainter(strokes)
            .shouldRepaint(StoryDrawingPainter(strokes)),
        isFalse,
      );
      expect(
        StoryDrawingPainter(strokes)
            .shouldRepaint(StoryDrawingPainter([...strokes])),
        isTrue,
      );
      const a = StoryShapePainter(shape: StoryShapeType.ellipse);
      expect(
          a.shouldRepaint(
              const StoryShapePainter(shape: StoryShapeType.ellipse)),
          isFalse);
      expect(
          a.shouldRepaint(const StoryShapePainter(shape: StoryShapeType.line)),
          isTrue);
    });
  });
}
