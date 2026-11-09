import 'package:meta/meta.dart';

import '../../core/enums/story_enums.dart';
import '../../core/models/geometry.dart';
import '../../core/models/story_color.dart';
import '../../core/models/story_source.dart';
import '../../core/utilities/json.dart';
import 'element_styles.dart';
import 'story_transform.dart';

/// Transform used by elements without a visual box, such as audio.
const StoryTransform _noTransform =
    StoryTransform(position: StoryPoint.zero, size: StorySize.zero);

/// An object placed inside a story item: image, text, sticker, and so on.
///
/// Elements are immutable values shared by the editor, the viewer, and the
/// exporter. Edits produce new instances through `copyWith`.
///
/// The hierarchy is sealed so every component can handle each type
/// exhaustively. Application-specific content uses [WidgetElement] or
/// [CustomElement] with a registered renderer.
@immutable
sealed class StoryElement {
  StoryElement({
    required this.id,
    required this.transform,
    this.opacity = 1,
    this.zIndex = 0,
    this.visible = true,
    this.locked = false,
    this.semanticLabel,
    JsonMap metadata = const {},
    JsonMap customData = const {},
  })  : metadata = freezeJsonMap(metadata, name: 'metadata'),
        customData = freezeJsonMap(customData, name: 'customData');

  /// Identifier, unique within the containing item.
  final String id;

  /// Placement on the canvas, in document coordinates.
  final StoryTransform transform;

  /// Opacity between 0 (invisible) and 1 (opaque).
  final double opacity;

  /// Paint order. Higher values paint on top; ties keep list order.
  final int zIndex;

  /// Whether the element is rendered.
  final bool visible;

  /// Whether editors must prevent selecting and transforming the element.
  final bool locked;

  /// Description announced by screen readers.
  final String? semanticLabel;

  /// Framework- and tool-level JSON-compatible annotations.
  final JsonMap metadata;

  /// Application-defined JSON-compatible data.
  final JsonMap customData;

  /// The serialization identifier of this element type, such as `image`.
  String get type;

  /// Whether the element has its own timeline (video, audio).
  bool get isTimeBased => false;

  /// Returns a copy with the common fields replaced.
  ///
  /// Generic tools (move, lock, reorder) use this without knowing the
  /// concrete type.
  StoryElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  });

  /// Type-specific values compared by [operator ==].
  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryElement &&
          other.runtimeType == runtimeType &&
          other.id == id &&
          other.transform == transform &&
          other.opacity == opacity &&
          other.zIndex == zIndex &&
          other.visible == visible &&
          other.locked == locked &&
          other.semanticLabel == semanticLabel &&
          deepEquals(other.metadata, metadata) &&
          deepEquals(other.customData, customData) &&
          deepEquals(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, id, transform, opacity, zIndex,
      visible, locked, semanticLabel, deepHash(_props));

  @override
  String toString() => '$runtimeType($id)';
}

/// A still or animated image.
final class ImageElement extends StoryElement {
  /// Creates an image element.
  ImageElement({
    required super.id,
    required super.transform,
    required this.source,
    this.fit = StoryFit.cover,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  });

  /// Serialization identifier.
  static const String typeId = 'image';

  /// The image to show.
  final StorySource source;

  /// How the image fills the element box.
  final StoryFit fit;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [source, fit];

  /// Returns a copy with the given fields replaced.
  ImageElement copyWith({
    String? id,
    StoryTransform? transform,
    StorySource? source,
    StoryFit? fit,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return ImageElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      source: source ?? this.source,
      fit: fit ?? this.fit,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  ImageElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// A video or audio element with its own timeline.
sealed class TimedMediaElement extends StoryElement {
  TimedMediaElement({
    required super.id,
    required super.transform,
    required this.source,
    this.volume = 1,
    this.muted = false,
    this.loop = false,
    this.trimStart = Duration.zero,
    this.trimEnd,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  });

  /// The media to play.
  final StorySource source;

  /// Volume between 0 and 1.
  final double volume;

  /// Whether audio output is muted.
  final bool muted;

  /// Whether playback restarts when the media ends.
  final bool loop;

  /// Offset into the media where playback starts.
  final Duration trimStart;

  /// Offset into the media where playback ends, or `null` for the media end.
  final Duration? trimEnd;

  @override
  bool get isTimeBased => true;
}

/// A video clip.
final class VideoElement extends TimedMediaElement {
  /// Creates a video element.
  VideoElement({
    required super.id,
    required super.transform,
    required super.source,
    this.fit = StoryFit.cover,
    super.volume,
    super.muted,
    super.loop,
    super.trimStart,
    super.trimEnd,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  });

  /// Serialization identifier.
  static const String typeId = 'video';

  /// How the video fills the element box.
  final StoryFit fit;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props =>
      [source, fit, volume, muted, loop, trimStart, trimEnd];

  /// Returns a copy with the given fields replaced.
  VideoElement copyWith({
    String? id,
    StoryTransform? transform,
    StorySource? source,
    StoryFit? fit,
    double? volume,
    bool? muted,
    bool? loop,
    Duration? trimStart,
    Duration? trimEnd,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return VideoElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      source: source ?? this.source,
      fit: fit ?? this.fit,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      loop: loop ?? this.loop,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  VideoElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// An audio clip. Audio has no visual box, so its transform defaults to empty.
final class AudioElement extends TimedMediaElement {
  /// Creates an audio element.
  AudioElement({
    required super.id,
    required super.source,
    super.transform = _noTransform,
    super.volume,
    super.muted,
    super.loop,
    super.trimStart,
    super.trimEnd,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  });

  /// Serialization identifier.
  static const String typeId = 'audio';

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [source, volume, muted, loop, trimStart, trimEnd];

  /// Returns a copy with the given fields replaced.
  AudioElement copyWith({
    String? id,
    StoryTransform? transform,
    StorySource? source,
    double? volume,
    bool? muted,
    bool? loop,
    Duration? trimStart,
    Duration? trimEnd,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return AudioElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      source: source ?? this.source,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      loop: loop ?? this.loop,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  AudioElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// A block of styled text.
final class TextElement extends StoryElement {
  /// Creates a text element.
  TextElement({
    required super.id,
    required super.transform,
    required this.text,
    StoryTextStyle? style,
    this.align = StoryTextAlign.center,
    this.backgroundColor,
    this.padding = StoryInsets.zero,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  }) : style = style ?? StoryTextStyle();

  /// Serialization identifier.
  static const String typeId = 'text';

  /// The text content.
  final String text;

  /// Typography.
  final StoryTextStyle style;

  /// Horizontal alignment within the element box.
  final StoryTextAlign align;

  /// Fill behind the text, if any.
  final StoryColor? backgroundColor;

  /// Space between the box edge and the text, in canvas units.
  final StoryInsets padding;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [text, style, align, backgroundColor, padding];

  /// Returns a copy with the given fields replaced.
  TextElement copyWith({
    String? id,
    StoryTransform? transform,
    String? text,
    StoryTextStyle? style,
    StoryTextAlign? align,
    StoryColor? backgroundColor,
    StoryInsets? padding,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return TextElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      text: text ?? this.text,
      style: style ?? this.style,
      align: align ?? this.align,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      padding: padding ?? this.padding,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  TextElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// An emoji, image, or provider-supplied sticker.
final class StickerElement extends StoryElement {
  /// Creates a sticker element.
  StickerElement({
    required super.id,
    required super.transform,
    required this.sticker,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  });

  /// Serialization identifier.
  static const String typeId = 'sticker';

  /// What the sticker shows.
  final StickerContent sticker;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [sticker];

  /// Returns a copy with the given fields replaced.
  StickerElement copyWith({
    String? id,
    StoryTransform? transform,
    StickerContent? sticker,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return StickerElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      sticker: sticker ?? this.sticker,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  StickerElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// A geometric shape.
final class ShapeElement extends StoryElement {
  /// Creates a shape element.
  ShapeElement({
    required super.id,
    required super.transform,
    required this.shape,
    this.fillColor,
    this.stroke,
    this.cornerRadius = 0,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  });

  /// Serialization identifier.
  static const String typeId = 'shape';

  /// Which shape to draw.
  final StoryShapeType shape;

  /// Interior fill, or `null` for none.
  final StoryColor? fillColor;

  /// Outline, or `null` for none.
  final StoryStroke? stroke;

  /// Corner radius for rectangles, in canvas units.
  final double cornerRadius;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [shape, fillColor, stroke, cornerRadius];

  /// Returns a copy with the given fields replaced.
  ShapeElement copyWith({
    String? id,
    StoryTransform? transform,
    StoryShapeType? shape,
    StoryColor? fillColor,
    StoryStroke? stroke,
    double? cornerRadius,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return ShapeElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      shape: shape ?? this.shape,
      fillColor: fillColor ?? this.fillColor,
      stroke: stroke ?? this.stroke,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  ShapeElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// Editable freehand drawing made of vector strokes.
final class DrawingElement extends StoryElement {
  /// Creates a drawing element.
  DrawingElement({
    required super.id,
    required super.transform,
    List<StoryDrawingStroke> strokes = const [],
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  }) : strokes = List.unmodifiable(strokes);

  /// Serialization identifier.
  static const String typeId = 'drawing';

  /// Strokes in drawing order.
  final List<StoryDrawingStroke> strokes;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [strokes];

  /// Returns a copy with the given fields replaced.
  DrawingElement copyWith({
    String? id,
    StoryTransform? transform,
    List<StoryDrawingStroke>? strokes,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return DrawingElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      strokes: strokes ?? this.strokes,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  DrawingElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// An application widget identified by a stable [widgetType].
///
/// Flutter widgets cannot be serialized. Instead the document stores the
/// [widgetType] and JSON [data]; the application registers a builder for that
/// type that turns the data back into a widget.
final class WidgetElement extends StoryElement {
  /// Creates a widget element.
  WidgetElement({
    required super.id,
    required super.transform,
    required this.widgetType,
    JsonMap data = const {},
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  }) : data = freezeJsonMap(data, name: 'data');

  /// Serialization identifier.
  static const String typeId = 'widget';

  /// Application-defined identifier of the widget builder.
  final String widgetType;

  /// JSON-compatible input for the widget builder.
  final JsonMap data;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [widgetType, data];

  /// Returns a copy with the given fields replaced.
  WidgetElement copyWith({
    String? id,
    StoryTransform? transform,
    String? widgetType,
    JsonMap? data,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return WidgetElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      widgetType: widgetType ?? this.widgetType,
      data: data ?? this.data,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  WidgetElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// An application-defined element type handled by a custom renderer.
///
/// Use this for content that needs its own rendering and editing logic (a
/// poll, a map, a 3D model) rather than a plain widget builder.
final class CustomElement extends StoryElement {
  /// Creates a custom element of [customType].
  CustomElement({
    required super.id,
    required super.transform,
    required this.customType,
    JsonMap data = const {},
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  }) : data = freezeJsonMap(data, name: 'data');

  /// Serialization identifier.
  static const String typeId = 'custom';

  /// Application-defined type, used to find the renderer.
  final String customType;

  /// JSON-compatible element data.
  final JsonMap data;

  @override
  String get type => typeId;

  @override
  List<Object?> get _props => [customType, data];

  /// Returns a copy with the given fields replaced.
  CustomElement copyWith({
    String? id,
    StoryTransform? transform,
    String? customType,
    JsonMap? data,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return CustomElement(
      id: id ?? this.id,
      transform: transform ?? this.transform,
      customType: customType ?? this.customType,
      data: data ?? this.data,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  CustomElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) =>
      copyWith(
        transform: transform,
        opacity: opacity,
        zIndex: zIndex,
        visible: visible,
        locked: locked,
        semanticLabel: semanticLabel,
        metadata: metadata,
        customData: customData,
      );
}

/// An element whose type this version of the framework does not recognize.
///
/// Produced when decoding a document written by a newer framework version or
/// by another application. The original JSON is kept so the element survives
/// a decode/encode round trip unchanged. Renderers skip it; editors may move,
/// hide, or delete it but cannot edit its content.
final class UnknownElement extends StoryElement {
  /// Creates a placeholder for an element of [originalType].
  UnknownElement({
    required super.id,
    required super.transform,
    required this.originalType,
    required JsonMap rawJson,
    super.opacity,
    super.zIndex,
    super.visible,
    super.locked,
    super.semanticLabel,
    super.metadata,
    super.customData,
  }) : rawJson = freezeJsonMap(rawJson, name: 'rawJson');

  /// The unrecognized serialization type.
  final String originalType;

  /// The element's original JSON, preserved for re-encoding.
  final JsonMap rawJson;

  @override
  String get type => originalType;

  @override
  List<Object?> get _props => [originalType, rawJson];

  @override
  UnknownElement copyWithCommon({
    StoryTransform? transform,
    double? opacity,
    int? zIndex,
    bool? visible,
    bool? locked,
    String? semanticLabel,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return UnknownElement(
      id: id,
      transform: transform ?? this.transform,
      originalType: originalType,
      rawJson: rawJson,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }
}
