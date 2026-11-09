import 'package:meta/meta.dart';

import '../../core/models/geometry.dart';
import '../../core/models/story_color.dart';
import '../../core/models/story_source.dart';
import '../../core/utilities/json.dart';

/// A drop shadow behind text or shapes.
@immutable
final class StoryShadow {
  /// Creates a shadow.
  const StoryShadow({
    this.color = const StoryColor(0x66000000),
    this.offset = StoryPoint.zero,
    this.blurRadius = 0,
  });

  /// Shadow color.
  final StoryColor color;

  /// Offset from the content, in canvas units.
  final StoryPoint offset;

  /// Blur radius, in canvas units.
  final double blurRadius;

  @override
  bool operator ==(Object other) =>
      other is StoryShadow &&
      other.color == color &&
      other.offset == offset &&
      other.blurRadius == blurRadius;

  @override
  int get hashCode => Object.hash(color, offset, blurRadius);
}

/// An outline around glyphs or shapes.
@immutable
final class StoryStroke {
  /// Creates a stroke.
  const StoryStroke({required this.color, required this.width});

  /// Stroke color.
  final StoryColor color;

  /// Stroke width, in canvas units.
  final double width;

  @override
  bool operator ==(Object other) =>
      other is StoryStroke && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);
}

/// Typography for a text element.
///
/// Sizes are in canvas units, so text scales with the canvas. Renderers may
/// additionally apply the platform text scale for accessibility.
@immutable
final class StoryTextStyle {
  /// Creates a text style.
  StoryTextStyle({
    this.fontFamily,
    this.fontSize = 48,
    this.fontWeight = 400,
    this.italic = false,
    this.color = StoryColor.white,
    this.lineHeight,
    this.letterSpacing = 0,
    List<StoryShadow> shadows = const [],
    this.stroke,
  }) : shadows = List.unmodifiable(shadows);

  /// Font family name, or `null` for the renderer's default.
  final String? fontFamily;

  /// Font size in canvas units.
  final double fontSize;

  /// Font weight from 100 (thin) to 900 (black).
  final int fontWeight;

  /// Whether glyphs are italic.
  final bool italic;

  /// Glyph color.
  final StoryColor color;

  /// Line height as a multiple of [fontSize], or `null` for the font default.
  final double? lineHeight;

  /// Extra space between letters, in canvas units.
  final double letterSpacing;

  /// Shadows painted behind the text.
  final List<StoryShadow> shadows;

  /// Outline painted around glyphs, where the renderer supports it.
  final StoryStroke? stroke;

  /// Returns a copy with the given fields replaced.
  StoryTextStyle copyWith({
    String? fontFamily,
    double? fontSize,
    int? fontWeight,
    bool? italic,
    StoryColor? color,
    double? lineHeight,
    double? letterSpacing,
    List<StoryShadow>? shadows,
    StoryStroke? stroke,
  }) {
    return StoryTextStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      italic: italic ?? this.italic,
      color: color ?? this.color,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      shadows: shadows ?? this.shadows,
      stroke: stroke ?? this.stroke,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryTextStyle &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.fontWeight == fontWeight &&
      other.italic == italic &&
      other.color == color &&
      other.lineHeight == lineHeight &&
      other.letterSpacing == letterSpacing &&
      deepEquals(other.shadows, shadows) &&
      other.stroke == stroke;

  @override
  int get hashCode => Object.hash(fontFamily, fontSize, fontWeight, italic,
      color, lineHeight, letterSpacing, deepHash(shadows), stroke);
}

/// Content of a sticker element.
@immutable
sealed class StickerContent {
  const StickerContent();
}

/// An emoji sticker.
final class EmojiSticker extends StickerContent {
  /// Creates a sticker showing [emoji].
  const EmojiSticker(this.emoji);

  /// The emoji character sequence.
  final String emoji;

  @override
  bool operator ==(Object other) =>
      other is EmojiSticker && other.emoji == emoji;

  @override
  int get hashCode => emoji.hashCode;
}

/// An image sticker, optionally animated (GIF, APNG, WebP).
final class ImageSticker extends StickerContent {
  /// Creates an image sticker loaded from [source].
  const ImageSticker(this.source, {this.animated = false});

  /// The sticker image.
  final StorySource source;

  /// Whether the image is animated.
  final bool animated;

  @override
  bool operator ==(Object other) =>
      other is ImageSticker &&
      other.source == source &&
      other.animated == animated;

  @override
  int get hashCode => Object.hash(source, animated);
}

/// A sticker supplied by an application-registered sticker provider.
final class CustomSticker extends StickerContent {
  /// Creates a sticker [stickerId] from the provider [providerId].
  CustomSticker({
    required this.providerId,
    required this.stickerId,
    JsonMap data = const {},
  }) : data = freezeJsonMap(data, name: 'data');

  /// The registered sticker provider.
  final String providerId;

  /// The sticker within the provider's collection.
  final String stickerId;

  /// Provider-specific JSON-compatible data.
  final JsonMap data;

  @override
  bool operator ==(Object other) =>
      other is CustomSticker &&
      other.providerId == providerId &&
      other.stickerId == stickerId &&
      deepEquals(other.data, data);

  @override
  int get hashCode => Object.hash(providerId, stickerId, deepHash(data));
}

/// The kind of geometric shape a shape element draws.
enum StoryShapeType {
  /// A rectangle, optionally with rounded corners.
  rectangle,

  /// An ellipse inscribed in the element box.
  ellipse,

  /// A straight line across the element box.
  line,

  /// An isosceles triangle pointing up.
  triangle,
}

/// The tool used to draw a stroke.
enum StoryDrawingTool {
  /// An opaque pen.
  pen,

  /// A soft-edged marker.
  marker,

  /// A translucent highlighter.
  highlighter,

  /// Clears previously drawn strokes in the same drawing.
  eraser,
}

/// One continuous freehand stroke.
///
/// [points] are in the drawing element's local coordinates, where `(0, 0)` is
/// the top-left of the element's unscaled box. Storing vector points (rather
/// than pixels) keeps drawings editable, resolution-independent, and
/// exportable.
@immutable
final class StoryDrawingStroke {
  /// Creates a stroke.
  StoryDrawingStroke({
    required List<StoryPoint> points,
    this.color = StoryColor.white,
    this.width = 8,
    this.opacity = 1,
    this.tool = StoryDrawingTool.pen,
  }) : points = List.unmodifiable(points);

  /// Sampled points along the stroke, in order.
  final List<StoryPoint> points;

  /// Stroke color (ignored by the eraser).
  final StoryColor color;

  /// Stroke width, in canvas units.
  final double width;

  /// Stroke opacity between 0 and 1.
  final double opacity;

  /// The tool that drew this stroke.
  final StoryDrawingTool tool;

  @override
  bool operator ==(Object other) =>
      other is StoryDrawingStroke &&
      deepEquals(other.points, points) &&
      other.color == color &&
      other.width == width &&
      other.opacity == opacity &&
      other.tool == tool;

  @override
  int get hashCode =>
      Object.hash(deepHash(points), color, width, opacity, tool);
}
