import 'package:meta/meta.dart';

import '../../core/enums/story_enums.dart';
import '../../core/models/geometry.dart';
import '../../core/models/story_color.dart';
import '../../core/models/story_source.dart';
import '../../core/utilities/json.dart';

/// What is painted behind a canvas or item.
@immutable
sealed class StoryBackground {
  const StoryBackground();
}

/// A solid color background.
final class StoryColorBackground extends StoryBackground {
  /// Creates a solid [color] background.
  const StoryColorBackground(this.color);

  /// The fill color.
  final StoryColor color;

  @override
  bool operator ==(Object other) =>
      other is StoryColorBackground && other.color == color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() => 'StoryColorBackground($color)';
}

/// A linear gradient background.
final class StoryGradientBackground extends StoryBackground {
  /// Creates a gradient through [colors].
  ///
  /// [begin] and [end] use alignment coordinates, where `(-1, -1)` is the
  /// top-left corner and `(1, 1)` the bottom-right. When given, [stops] must
  /// have one entry per color, each between 0 and 1.
  StoryGradientBackground({
    required List<StoryColor> colors,
    List<double>? stops,
    this.begin = const StoryPoint(0, -1),
    this.end = const StoryPoint(0, 1),
  })  : colors = List.unmodifiable(colors),
        stops = stops == null ? null : List.unmodifiable(stops);

  /// Gradient colors, in order.
  final List<StoryColor> colors;

  /// Positions of each color between 0 and 1, or `null` for even spacing.
  final List<double>? stops;

  /// Start of the gradient in alignment coordinates.
  final StoryPoint begin;

  /// End of the gradient in alignment coordinates.
  final StoryPoint end;

  @override
  bool operator ==(Object other) =>
      other is StoryGradientBackground &&
      deepEquals(other.colors, colors) &&
      deepEquals(other.stops, stops) &&
      other.begin == begin &&
      other.end == end;

  @override
  int get hashCode =>
      Object.hash(deepHash(colors), deepHash(stops), begin, end);

  @override
  String toString() => 'StoryGradientBackground(${colors.length} colors)';
}

/// An image or video background.
final class StoryMediaBackground extends StoryBackground {
  /// Creates a background showing [source].
  const StoryMediaBackground(this.source, {this.fit = StoryFit.cover});

  /// The media to show.
  final StorySource source;

  /// How the media fills the background.
  final StoryFit fit;

  @override
  bool operator ==(Object other) =>
      other is StoryMediaBackground &&
      other.source == source &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(source, fit);

  @override
  String toString() => 'StoryMediaBackground($source, ${fit.name})';
}
