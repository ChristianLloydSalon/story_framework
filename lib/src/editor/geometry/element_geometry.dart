import 'dart:math' as math;

import '../../composition/elements/story_element.dart';
import '../../composition/elements/story_transform.dart';
import '../../composition/items/story_item.dart';
import '../../core/models/geometry.dart';

/// Geometry of elements on the canvas: rotated corners, bounds, conversion
/// between canvas and element-local coordinates, and hit testing.
///
/// Element-local coordinates have `(0, 0)` at the top-left of the element's
/// unscaled, unrotated box (the space drawing strokes use).
abstract final class StoryElementGeometry {
  /// Rotates [point] around the origin by [radians] (clockwise on screen).
  static StoryPoint rotate(StoryPoint point, double radians) {
    if (radians == 0) return point;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return StoryPoint(
        point.x * cos - point.y * sin, point.x * sin + point.y * cos);
  }

  /// The four corners of [transform]'s box on the canvas, clockwise from
  /// the top-left of the unrotated box.
  static List<StoryPoint> corners(StoryTransform transform) {
    final half = transform.scaledSize * 0.5;
    return [
      StoryPoint(-half.width, -half.height),
      StoryPoint(half.width, -half.height),
      StoryPoint(half.width, half.height),
      StoryPoint(-half.width, half.height),
    ]
        .map(
            (offset) => transform.position + rotate(offset, transform.rotation))
        .toList();
  }

  /// The axis-aligned bounds of [transform]'s rotated box.
  static StoryRect bounds(StoryTransform transform) {
    final points = corners(transform);
    var l = points.first.x, r = points.first.x;
    var t = points.first.y, b = points.first.y;
    for (final p in points.skip(1)) {
      l = math.min(l, p.x);
      r = math.max(r, p.x);
      t = math.min(t, p.y);
      b = math.max(b, p.y);
    }
    return StoryRect.fromLTWH(l, t, r - l, b - t);
  }

  /// The bounds of every transform in [transforms], or `null` if empty.
  static StoryRect? unionBounds(Iterable<StoryTransform> transforms) {
    StoryRect? result;
    for (final transform in transforms) {
      final box = bounds(transform);
      result = result == null ? box : result.union(box);
    }
    return result;
  }

  /// Converts a canvas point to [transform]'s element-local coordinates.
  static StoryPoint toLocal(StoryTransform transform, StoryPoint canvasPoint) {
    final scale = transform.scale == 0 ? 1 : transform.scale;
    var offset = rotate(canvasPoint - transform.position, -transform.rotation);
    offset = StoryPoint(
      (transform.flipHorizontal ? -offset.x : offset.x) / scale,
      (transform.flipVertical ? -offset.y : offset.y) / scale,
    );
    return StoryPoint(
      offset.x + transform.size.width / 2,
      offset.y + transform.size.height / 2,
    );
  }

  /// Converts an element-local point to canvas coordinates.
  static StoryPoint toCanvas(StoryTransform transform, StoryPoint localPoint) {
    var offset = StoryPoint(
      (localPoint.x - transform.size.width / 2) * transform.scale,
      (localPoint.y - transform.size.height / 2) * transform.scale,
    );
    offset = StoryPoint(
      transform.flipHorizontal ? -offset.x : offset.x,
      transform.flipVertical ? -offset.y : offset.y,
    );
    return transform.position + rotate(offset, transform.rotation);
  }

  /// Whether [canvasPoint] lies inside [transform]'s rotated box, with an
  /// optional [tolerance] in canvas units.
  static bool contains(StoryTransform transform, StoryPoint canvasPoint,
      {double tolerance = 0}) {
    final local = toLocal(transform, canvasPoint);
    final slack = tolerance / (transform.scale == 0 ? 1 : transform.scale);
    return local.x >= -slack &&
        local.y >= -slack &&
        local.x <= transform.size.width + slack &&
        local.y <= transform.size.height + slack;
  }

  /// The topmost visible element of [item] at [canvasPoint], or `null`.
  ///
  /// Locked elements are skipped unless [includeLocked] is set.
  static StoryElement? hitTest(
    StoryItem item,
    StoryPoint canvasPoint, {
    bool includeLocked = false,
    double tolerance = 0,
  }) {
    final ordered = item.elementsInPaintOrder;
    for (var i = ordered.length - 1; i >= 0; i--) {
      final element = ordered[i];
      if (!element.visible || (element.locked && !includeLocked)) continue;
      if (element.transform.size.isEmpty) continue;
      if (contains(element.transform, canvasPoint, tolerance: tolerance)) {
        return element;
      }
    }
    return null;
  }

  /// Visible, unlocked elements of [item] whose bounds overlap [rect].
  static List<StoryElement> elementsInRect(StoryItem item, StoryRect rect) => [
        for (final element in item.elementsInPaintOrder)
          if (element.visible &&
              !element.locked &&
              !element.transform.size.isEmpty &&
              bounds(element.transform).overlaps(rect))
            element,
      ];
}
