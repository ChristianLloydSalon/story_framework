import 'package:meta/meta.dart';

import '../../core/enums/story_enums.dart';
import '../../core/models/geometry.dart';
import '../../core/models/story_color.dart';
import 'story_background.dart';

/// The design surface every item in a document is composed on.
///
/// All element coordinates are in this canvas's logical units, origin at the
/// top-left. Viewers and editors scale the canvas to the screen with
/// [scalingBehavior], so documents look the same on every device.
@immutable
final class StoryCanvasConfiguration {
  /// Creates a canvas configuration.
  const StoryCanvasConfiguration({
    required this.width,
    required this.height,
    this.background = const StoryColorBackground(StoryColor.black),
    this.safeArea = StoryInsets.zero,
    this.scalingBehavior = StoryScalingBehavior.contain,
  });

  /// 1080×1920 portrait (9:16), the common story format.
  static const StoryCanvasConfiguration portrait =
      StoryCanvasConfiguration(width: 1080, height: 1920);

  /// 1080×1080 square (1:1).
  static const StoryCanvasConfiguration square =
      StoryCanvasConfiguration(width: 1080, height: 1080);

  /// 1920×1080 landscape (16:9).
  static const StoryCanvasConfiguration landscape =
      StoryCanvasConfiguration(width: 1920, height: 1080);

  /// Canvas width in logical units.
  final double width;

  /// Canvas height in logical units.
  final double height;

  /// Background painted behind items without their own background.
  final StoryBackground background;

  /// Region near the edges kept clear of important content (for example,
  /// under the progress bar and header).
  final StoryInsets safeArea;

  /// How the canvas is fitted to the viewport.
  final StoryScalingBehavior scalingBehavior;

  /// The canvas size.
  StorySize get size => StorySize(width, height);

  /// `width / height`.
  double get aspectRatio => size.aspectRatio;

  /// The full canvas rectangle.
  StoryRect get bounds => StoryRect.fromLTWH(0, 0, width, height);

  /// The canvas rectangle inside [safeArea].
  StoryRect get safeBounds => StoryRect.fromLTWH(
        safeArea.left,
        safeArea.top,
        width - safeArea.left - safeArea.right,
        height - safeArea.top - safeArea.bottom,
      );

  /// Returns a copy with the given fields replaced.
  StoryCanvasConfiguration copyWith({
    double? width,
    double? height,
    StoryBackground? background,
    StoryInsets? safeArea,
    StoryScalingBehavior? scalingBehavior,
  }) {
    return StoryCanvasConfiguration(
      width: width ?? this.width,
      height: height ?? this.height,
      background: background ?? this.background,
      safeArea: safeArea ?? this.safeArea,
      scalingBehavior: scalingBehavior ?? this.scalingBehavior,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryCanvasConfiguration &&
      other.width == width &&
      other.height == height &&
      other.background == background &&
      other.safeArea == safeArea &&
      other.scalingBehavior == scalingBehavior;

  @override
  int get hashCode =>
      Object.hash(width, height, background, safeArea, scalingBehavior);

  @override
  String toString() => 'StoryCanvasConfiguration(${width}x$height)';
}
