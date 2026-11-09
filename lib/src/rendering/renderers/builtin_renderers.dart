import 'package:flutter/widgets.dart';

import '../../composition/elements/element_styles.dart';
import '../../composition/elements/story_element.dart';
import '../../core/errors/story_exceptions.dart';
import '../../core/models/story_color.dart';
import '../../core/models/story_source.dart';
import '../contracts/story_element_renderer.dart';
import '../conversions.dart';
import 'interactive/story_interactive_renderer.dart';
import 'video_renderer.dart';

/// The renderers included by `StoryRendererRegistry.withDefaults`.
List<StoryElementRenderer<StoryElement>> defaultStoryRenderers() => const [
      StoryImageRenderer(),
      StoryVideoRenderer(),
      StoryTextRenderer(),
      StoryStickerRenderer(),
      StoryShapeRenderer(),
      StoryDrawingRenderer(),
      StoryAudioRenderer(),
      StoryInteractiveRenderer(),
    ];

/// An image filling its box, with loading and error states.
///
/// Used by the image and sticker renderers; reusable by custom renderers.
class StoryImageContent extends StatelessWidget {
  /// Creates image content for [source] in `renderContext.element`.
  const StoryImageContent({
    required this.renderContext,
    required this.source,
    required this.fit,
    super.key,
  });

  /// The element being rendered.
  final StoryRenderContext renderContext;

  /// The image to show; asset references are resolved.
  final StorySource source;

  /// How the image fills the box.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? provider;
    try {
      provider = renderContext.imageProviderFor(source);
    } on StoryException catch (error, stack) {
      return StoryElementError(
          renderContext: renderContext, error: error, stack: stack);
    }
    if (provider == null) {
      return StoryElementError(
        renderContext: renderContext,
        error: UnsupportedStoryTypeException('Cannot load $source as an image'),
      );
    }
    return Image(
      image: provider,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null
              ? child
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryElementLoading(renderContext: renderContext),
                    child,
                  ],
                ),
      errorBuilder: (context, error, stack) => StoryElementError(
          renderContext: renderContext, error: error, stack: stack),
    );
  }
}

/// Renders [ImageElement]s with Flutter's [Image] widget.
final class StoryImageRenderer extends StoryElementRenderer<ImageElement> {
  /// Creates the image renderer.
  const StoryImageRenderer();

  @override
  String get id => ImageElement.typeId;

  @override
  Widget buildElement(
    BuildContext context,
    ImageElement element,
    StoryRenderContext renderContext,
  ) =>
      StoryImageContent(
        renderContext: renderContext,
        source: element.source,
        fit: element.fit.toBoxFit(),
      );
}

/// Renders [TextElement]s, including background, padding, shadows, and an
/// outline stroke.
final class StoryTextRenderer extends StoryElementRenderer<TextElement> {
  /// Creates the text renderer.
  const StoryTextRenderer();

  @override
  String get id => TextElement.typeId;

  @override
  Widget buildElement(
    BuildContext context,
    TextElement element,
    StoryRenderContext renderContext,
  ) {
    final style = element.style;
    final textScaler = renderContext.options.textScaler;
    final stroke = style.stroke;
    return Container(
      color: element.backgroundColor?.toColor(),
      padding: element.padding.toEdgeInsets(),
      alignment: element.align.toAlignment(),
      child: stroke == null
          ? _TextLayer(
              element: element,
              style: style.toTextStyle(),
              textScaler: textScaler,
            )
          : Stack(
              children: [
                // The outline sits behind the fill and carries the shadows.
                _TextLayer(
                  element: element,
                  textScaler: textScaler,
                  style: style.toTextStyle(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = stroke.width
                      ..strokeJoin = StrokeJoin.round
                      ..color = stroke.color.toColor(),
                  ),
                ),
                _TextLayer(
                  element: element,
                  textScaler: textScaler,
                  style: style.toTextStyle(includeShadows: false),
                ),
              ],
            ),
    );
  }
}

class _TextLayer extends StatelessWidget {
  const _TextLayer({
    required this.element,
    required this.style,
    required this.textScaler,
  });

  final TextElement element;
  final TextStyle style;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) => Text(
        element.text,
        style: style,
        textAlign: element.align.toTextAlign(),
        textScaler: textScaler,
      );
}

/// Builds a [CustomSticker] supplied by an application sticker provider.
typedef StoryCustomStickerBuilder = Widget Function(
  BuildContext context,
  CustomSticker sticker,
  StickerElement element,
  StoryRenderContext renderContext,
);

/// Renders [StickerElement]s: emoji, image stickers, and provider stickers
/// with a builder in [customBuilders].
final class StoryStickerRenderer extends StoryElementRenderer<StickerElement> {
  /// Creates the sticker renderer.
  const StoryStickerRenderer({this.customBuilders = const {}});

  /// Builders for [CustomSticker]s, keyed by [CustomSticker.providerId].
  final Map<String, StoryCustomStickerBuilder> customBuilders;

  @override
  String get id => StickerElement.typeId;

  @override
  bool supports(StoryElement element) =>
      element is StickerElement &&
      switch (element.sticker) {
        CustomSticker(:final providerId) =>
          customBuilders.containsKey(providerId),
        EmojiSticker() || ImageSticker() => true,
      };

  @override
  Widget buildElement(
    BuildContext context,
    StickerElement element,
    StoryRenderContext renderContext,
  ) {
    return switch (element.sticker) {
      EmojiSticker(:final emoji) => FittedBox(
          child: Text(
            emoji,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(fontSize: 200, height: 1),
          ),
        ),
      ImageSticker(:final source) => StoryImageContent(
          renderContext: renderContext,
          source: source,
          fit: BoxFit.contain,
        ),
      final CustomSticker sticker => switch (
            customBuilders[sticker.providerId]) {
          final builder? => builder(context, sticker, element, renderContext),
          null => StoryElementError(
              renderContext: renderContext,
              error: RendererNotRegisteredException(element.type,
                  'No builder for sticker provider "${sticker.providerId}"'),
            ),
        },
    };
  }
}

/// Renders [ShapeElement]s with a [CustomPaint].
final class StoryShapeRenderer extends StoryElementRenderer<ShapeElement> {
  /// Creates the shape renderer.
  const StoryShapeRenderer();

  @override
  String get id => ShapeElement.typeId;

  @override
  Widget buildElement(
    BuildContext context,
    ShapeElement element,
    StoryRenderContext renderContext,
  ) =>
      CustomPaint(
        painter: StoryShapePainter(
          shape: element.shape,
          fillColor: element.fillColor,
          stroke: element.stroke,
          cornerRadius: element.cornerRadius,
        ),
        child: const SizedBox.expand(),
      );
}

/// Paints a [StoryShapeType] filling the canvas size.
class StoryShapePainter extends CustomPainter {
  /// Creates a shape painter.
  const StoryShapePainter({
    required this.shape,
    this.fillColor,
    this.stroke,
    this.cornerRadius = 0,
  });

  /// The shape to paint.
  final StoryShapeType shape;

  /// Interior color, or `null` for none.
  final StoryColor? fillColor;

  /// Outline, or `null` for none.
  final StoryStroke? stroke;

  /// Rectangle corner radius.
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = switch (shape) {
      StoryShapeType.rectangle => Path()
        ..addRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius))),
      StoryShapeType.ellipse => Path()..addOval(rect),
      StoryShapeType.line => Path()
        ..moveTo(0, size.height / 2)
        ..lineTo(size.width, size.height / 2),
      StoryShapeType.triangle => Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
    };

    final fill = fillColor;
    if (fill != null && shape != StoryShapeType.line) {
      canvas.drawPath(path, Paint()..color = fill.toColor());
    }
    final outline = stroke;
    if (outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outline.width
          ..strokeCap = StrokeCap.round
          ..color = outline.color.toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(StoryShapePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.stroke != stroke ||
      oldDelegate.cornerRadius != cornerRadius;
}

/// Renders [DrawingElement] strokes as vector paths.
final class StoryDrawingRenderer extends StoryElementRenderer<DrawingElement> {
  /// Creates the drawing renderer.
  const StoryDrawingRenderer();

  @override
  String get id => DrawingElement.typeId;

  @override
  Widget buildElement(
    BuildContext context,
    DrawingElement element,
    StoryRenderContext renderContext,
  ) =>
      CustomPaint(
        painter: StoryDrawingPainter(element.strokes),
        child: const SizedBox.expand(),
      );
}

/// Paints freehand strokes in drawing-local coordinates.
///
/// Strokes are painted into their own layer so the eraser clears only earlier
/// strokes of the same drawing, not the content underneath.
class StoryDrawingPainter extends CustomPainter {
  /// Creates a painter for [strokes].
  const StoryDrawingPainter(this.strokes);

  /// Strokes in drawing order.
  final List<StoryDrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final opacity = switch (stroke.tool) {
        StoryDrawingTool.highlighter => stroke.opacity * 0.4,
        _ => stroke.opacity,
      };
      final paint = Paint()
        ..isAntiAlias = true
        ..strokeWidth = stroke.width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = stroke.tool == StoryDrawingTool.highlighter
            ? StrokeCap.square
            : StrokeCap.round
        ..color = stroke.color
            .withAlpha((stroke.color.alpha * opacity).round().clamp(0, 255))
            .toColor();
      if (stroke.tool == StoryDrawingTool.eraser) {
        paint
          ..blendMode = BlendMode.clear
          ..color = const Color(0xFF000000);
      }

      final first = stroke.points.first.toOffset();
      if (stroke.points.length == 1) {
        canvas.drawCircle(first, stroke.width / 2, paint);
        continue;
      }
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
    canvas.restore();
  }

  /// Drawings are immutable, so a new stroke list means new content.
  @override
  bool shouldRepaint(StoryDrawingPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes);
}

/// Handles [AudioElement]s, which have no visual content.
///
/// Registered so audio is recognized as supported rather than reported as
/// missing a renderer.
final class StoryAudioRenderer extends StoryElementRenderer<AudioElement> {
  /// Creates the audio renderer.
  const StoryAudioRenderer();

  @override
  String get id => AudioElement.typeId;

  @override
  Widget buildElement(
    BuildContext context,
    AudioElement element,
    StoryRenderContext renderContext,
  ) =>
      const SizedBox.shrink();
}

/// Builds the widget for a [WidgetElement].
typedef StoryWidgetElementBuilder = Widget Function(
  BuildContext context,
  WidgetElement element,
  StoryRenderContext renderContext,
);

/// Renders [WidgetElement]s with application builders keyed by
/// [WidgetElement.widgetType].
///
/// ```dart
/// StoryWidgetElementRenderer({
///   'poll': (context, element, _) => PollWidget(element.data),
/// })
/// ```
final class StoryWidgetElementRenderer
    extends StoryElementRenderer<WidgetElement> {
  /// Creates a renderer with [builders] keyed by widget type.
  StoryWidgetElementRenderer(Map<String, StoryWidgetElementBuilder> builders)
      : builders = Map.unmodifiable(builders);

  /// Builders keyed by [WidgetElement.widgetType].
  final Map<String, StoryWidgetElementBuilder> builders;

  @override
  String get id => WidgetElement.typeId;

  @override
  bool supports(StoryElement element) =>
      element is WidgetElement && builders.containsKey(element.widgetType);

  @override
  Widget buildElement(
    BuildContext context,
    WidgetElement element,
    StoryRenderContext renderContext,
  ) =>
      switch (builders[element.widgetType]) {
        final builder? => builder(context, element, renderContext),
        null => StoryElementError(
            renderContext: renderContext,
            error: RendererNotRegisteredException(element.type,
                'No builder for widget type "${element.widgetType}"'),
          ),
      };
}

/// Builds the widget for a [CustomElement].
typedef StoryCustomElementBuilder = Widget Function(
  BuildContext context,
  CustomElement element,
  StoryRenderContext renderContext,
);

/// Renders [CustomElement]s of one [customType] with [builder].
///
/// For renderers that need shared resources or more control, subclass
/// [StoryElementRenderer] directly.
final class StoryCustomElementRenderer
    extends StoryElementRenderer<CustomElement> {
  /// Creates a renderer for custom elements of [customType].
  const StoryCustomElementRenderer({
    required this.customType,
    required this.builder,
  });

  /// The [CustomElement.customType] this renderer handles.
  final String customType;

  /// Builds the element.
  final StoryCustomElementBuilder builder;

  @override
  String get id => 'custom:$customType';

  @override
  bool supports(StoryElement element) =>
      element is CustomElement && element.customType == customType;

  @override
  Widget buildElement(
    BuildContext context,
    CustomElement element,
    StoryRenderContext renderContext,
  ) =>
      builder(context, element, renderContext);
}
