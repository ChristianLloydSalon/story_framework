import 'dart:math' as math;

import '../../composition/elements/story_transform.dart';
import '../../core/models/geometry.dart';
import 'element_geometry.dart';

/// Pure transform calculations used by the canvas handles.
///
/// All inputs and outputs are canvas units; they never depend on zoom.
abstract final class StoryTransformMath {
  /// The angle of [point] around [center], in radians.
  static double angleAround(StoryPoint center, StoryPoint point) =>
      math.atan2(point.y - center.y, point.x - center.x);

  /// Distance between two points.
  static double distance(StoryPoint a, StoryPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Scales every transform in [originals] by [factor] around [center]:
  /// positions move away from (or toward) the center and scales multiply.
  ///
  /// [minSize] limits how small the smallest element's scaled box can get.
  static Map<String, StoryTransform> scaleAround(
    Map<String, StoryTransform> originals,
    StoryPoint center,
    double factor, {
    double minSize = 1,
  }) {
    var limited = factor;
    for (final transform in originals.values) {
      final shortest =
          math.min(transform.scaledSize.width, transform.scaledSize.height);
      if (shortest > 0 && shortest * limited < minSize) {
        limited = minSize / shortest;
      }
    }
    return {
      for (final MapEntry(:key, value: t) in originals.entries)
        key: t.copyWith(
          position: center + (t.position - center) * limited,
          scale: t.scale * limited,
        ),
    };
  }

  /// Rotates every transform in [originals] by [radians] around [center]:
  /// positions orbit the center and rotations add up.
  static Map<String, StoryTransform> rotateAround(
    Map<String, StoryTransform> originals,
    StoryPoint center,
    double radians,
  ) {
    return {
      for (final MapEntry(:key, value: t) in originals.entries)
        key: t.copyWith(
          position: center +
              StoryElementGeometry.rotate(t.position - center, radians),
          rotation: t.rotation + radians,
        ),
    };
  }

  /// Resizes [original] along its own x axis ([horizontal]) or y axis by
  /// dragging an edge handle from [start] to [current], keeping the center
  /// fixed. The result is at least [minSize] canvas units.
  static StoryTransform resizeEdge(
    StoryTransform original, {
    required bool horizontal,
    required StoryPoint start,
    required StoryPoint current,
    double minSize = 1,
  }) {
    final moved =
        StoryElementGeometry.rotate(current - start, -original.rotation);
    final scale = original.scale == 0 ? 1 : original.scale;
    if (horizontal) {
      final width =
          math.max(minSize / scale, original.size.width + 2 * moved.x / scale);
      return original.copyWith(size: StorySize(width, original.size.height));
    }
    final height =
        math.max(minSize / scale, original.size.height + 2 * moved.y / scale);
    return original.copyWith(size: StorySize(original.size.width, height));
  }

  /// Where the rotation handle of [transform] sits: [offset] canvas units
  /// above the top edge's midpoint, along the element's own up direction.
  static StoryPoint rotationHandle(StoryTransform transform, double offset) {
    final up = StoryElementGeometry.rotate(
      StoryPoint(0, -(transform.scaledSize.height / 2 + offset)),
      transform.rotation,
    );
    return transform.position + up;
  }

  /// Midpoint of [transform]'s right edge (horizontal) or bottom edge.
  static StoryPoint edgeHandle(StoryTransform transform,
      {required bool horizontal}) {
    final half = transform.scaledSize * 0.5;
    final local =
        horizontal ? StoryPoint(half.width, 0) : StoryPoint(0, half.height);
    return transform.position +
        StoryElementGeometry.rotate(local, transform.rotation);
  }
}
