import 'package:flutter/widgets.dart';

import '../composition/elements/element_styles.dart';
import '../core/enums/story_enums.dart';
import '../core/models/geometry.dart';
import '../core/models/story_color.dart';

/// Conversions from Flutter-free model types to Flutter types.
///
/// Kept at the rendering edge so the composition model stays independent of
/// `dart:ui`.
extension StoryColorToFlutter on StoryColor {
  /// This color as a Flutter [Color].
  Color toColor() => Color(value);
}

/// Converts [StoryPoint] to Flutter geometry.
extension StoryPointToFlutter on StoryPoint {
  /// This point as an [Offset].
  Offset toOffset() => Offset(x, y);

  /// This point, in alignment coordinates, as an [Alignment].
  Alignment toAlignment() => Alignment(x, y);
}

/// Converts [StoryInsets] to Flutter geometry.
extension StoryInsetsToFlutter on StoryInsets {
  /// These insets as [EdgeInsets].
  EdgeInsets toEdgeInsets() => EdgeInsets.fromLTRB(left, top, right, bottom);
}

/// Converts [StoryFit] to [BoxFit].
extension StoryFitToFlutter on StoryFit {
  /// The equivalent [BoxFit].
  BoxFit toBoxFit() => switch (this) {
        StoryFit.fill => BoxFit.fill,
        StoryFit.contain => BoxFit.contain,
        StoryFit.cover => BoxFit.cover,
        StoryFit.fitWidth => BoxFit.fitWidth,
        StoryFit.fitHeight => BoxFit.fitHeight,
        StoryFit.none => BoxFit.none,
        StoryFit.scaleDown => BoxFit.scaleDown,
      };
}

/// Converts [StoryScalingBehavior] to [BoxFit].
extension StoryScalingToFlutter on StoryScalingBehavior {
  /// The [BoxFit] used to fit the canvas into the viewport.
  BoxFit toBoxFit() => switch (this) {
        StoryScalingBehavior.contain => BoxFit.contain,
        StoryScalingBehavior.cover => BoxFit.cover,
        StoryScalingBehavior.fill => BoxFit.fill,
      };
}

/// Converts [StoryTextAlign] to Flutter text alignment.
extension StoryTextAlignToFlutter on StoryTextAlign {
  /// The equivalent [TextAlign].
  TextAlign toTextAlign() => switch (this) {
        StoryTextAlign.left => TextAlign.left,
        StoryTextAlign.right => TextAlign.right,
        StoryTextAlign.center => TextAlign.center,
        StoryTextAlign.justify => TextAlign.justify,
        StoryTextAlign.start => TextAlign.start,
        StoryTextAlign.end => TextAlign.end,
      };

  /// Where a block of text with this alignment sits horizontally in its box.
  AlignmentDirectional toAlignment() => switch (this) {
        StoryTextAlign.left => AlignmentDirectional.centerStart,
        StoryTextAlign.start => AlignmentDirectional.centerStart,
        StoryTextAlign.right => AlignmentDirectional.centerEnd,
        StoryTextAlign.end => AlignmentDirectional.centerEnd,
        StoryTextAlign.center ||
        StoryTextAlign.justify =>
          AlignmentDirectional.center,
      };
}

/// Converts [StoryTextStyle] to a Flutter [TextStyle].
extension StoryTextStyleToFlutter on StoryTextStyle {
  /// The equivalent [TextStyle], without the stroke.
  ///
  /// `fontWeight` is rounded to the nearest of Flutter's nine weights. When
  /// [foreground] is given it paints the glyphs instead of [color], and
  /// [includeShadows] controls whether shadows are kept.
  TextStyle toTextStyle({Paint? foreground, bool includeShadows = true}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: _weight(fontWeight),
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: foreground == null ? color.toColor() : null,
        foreground: foreground,
        height: lineHeight,
        letterSpacing: letterSpacing,
        shadows: [
          if (includeShadows)
            for (final shadow in shadows)
              Shadow(
                color: shadow.color.toColor(),
                offset: shadow.offset.toOffset(),
                blurRadius: shadow.blurRadius,
              ),
        ],
      );

  static FontWeight _weight(int weight) {
    final index = ((weight / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }
}
