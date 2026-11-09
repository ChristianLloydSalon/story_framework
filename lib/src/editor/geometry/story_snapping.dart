import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../core/models/geometry.dart';

/// The orientation of an alignment guide.
enum StoryGuideAxis {
  /// A vertical line at an x position.
  vertical,

  /// A horizontal line at a y position.
  horizontal,
}

/// An alignment guide shown while an element snaps to it.
@immutable
final class StoryGuide {
  /// Creates a guide at [position] (canvas units) along [axis].
  const StoryGuide(this.axis, this.position);

  /// Line orientation.
  final StoryGuideAxis axis;

  /// x for vertical guides, y for horizontal ones.
  final double position;

  @override
  bool operator ==(Object other) =>
      other is StoryGuide && other.axis == axis && other.position == position;

  @override
  int get hashCode => Object.hash(axis, position);

  @override
  String toString() => 'StoryGuide(${axis.name}, $position)';
}

/// The outcome of snapping a move.
@immutable
final class StorySnapResult {
  /// Creates a result.
  const StorySnapResult(this.delta, this.guides);

  /// The adjusted movement.
  final StoryPoint delta;

  /// Guides the moved box now aligns with.
  final List<StoryGuide> guides;
}

/// Snapping rules for moving and rotating elements.
abstract final class StorySnapping {
  /// Adjusts [delta] so the edges or center of [moving] (before the move)
  /// align with the edges or centers of [targets], when within [threshold]
  /// canvas units on each axis.
  static StorySnapResult snapMove({
    required StoryRect moving,
    required StoryPoint delta,
    required Iterable<StoryRect> targets,
    required double threshold,
  }) {
    final moved = StoryRect.fromLTWH(moving.left + delta.x,
        moving.top + delta.y, moving.width, moving.height);
    final xs = [moved.left, moved.center.x, moved.right];
    final ys = [moved.top, moved.center.y, moved.bottom];
    final lineXs = <double>[];
    final lineYs = <double>[];
    for (final target in targets) {
      lineXs.addAll([target.left, target.center.x, target.right]);
      lineYs.addAll([target.top, target.center.y, target.bottom]);
    }

    final snapX = _closest(xs, lineXs, threshold);
    final snapY = _closest(ys, lineYs, threshold);
    final adjusted = StoryPoint(
      delta.x + (snapX?.$2 ?? 0),
      delta.y + (snapY?.$2 ?? 0),
    );
    return StorySnapResult(adjusted, [
      if (snapX != null) StoryGuide(StoryGuideAxis.vertical, snapX.$1),
      if (snapY != null) StoryGuide(StoryGuideAxis.horizontal, snapY.$1),
    ]);
  }

  /// The best (line, correction) pair within [threshold], or `null`.
  static (double, double)? _closest(
    List<double> values,
    List<double> lines,
    double threshold,
  ) {
    (double, double)? best;
    for (final value in values) {
      for (final line in lines) {
        final correction = line - value;
        if (correction.abs() > threshold) continue;
        if (best == null || correction.abs() < best.$2.abs()) {
          best = (line, correction);
        }
      }
    }
    return best;
  }

  /// Snaps [radians] to the nearest multiple of [stepDegrees] when within
  /// [toleranceDegrees] of it.
  static double snapRotation(
    double radians, {
    double stepDegrees = 45,
    double toleranceDegrees = 4,
  }) {
    final degrees = radians * 180 / math.pi;
    final nearest = (degrees / stepDegrees).round() * stepDegrees;
    if ((degrees - nearest).abs() > toleranceDegrees) return radians;
    return nearest * math.pi / 180;
  }
}
