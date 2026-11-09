import 'package:meta/meta.dart';

import '../../core/models/geometry.dart';

/// Placement of an element on the story canvas, in document coordinates.
///
/// [position] is the element's **center**. Rotation and scale are applied
/// around that center, so moving, rotating, and scaling are independent edits.
@immutable
final class StoryTransform {
  /// Creates a transform.
  const StoryTransform({
    required this.position,
    required this.size,
    this.rotation = 0,
    this.scale = 1,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  /// A transform whose unscaled box is [rect].
  StoryTransform.fromRect(StoryRect rect, {this.rotation = 0, this.scale = 1})
      : position = rect.center,
        size = rect.size,
        flipHorizontal = false,
        flipVertical = false;

  /// Center of the element in canvas coordinates.
  final StoryPoint position;

  /// Unscaled size of the element's box.
  final StorySize size;

  /// Clockwise rotation in radians.
  final double rotation;

  /// Uniform scale factor applied to [size].
  final double scale;

  /// Whether the content is mirrored horizontally.
  final bool flipHorizontal;

  /// Whether the content is mirrored vertically.
  final bool flipVertical;

  /// [size] multiplied by [scale].
  StorySize get scaledSize => size * scale;

  /// The scaled box before rotation.
  StoryRect get unrotatedBounds => StoryRect.fromCenter(position, scaledSize);

  /// Returns a copy moved by [delta].
  StoryTransform translate(StoryPoint delta) =>
      copyWith(position: position + delta);

  /// Returns a copy with the given fields replaced.
  StoryTransform copyWith({
    StoryPoint? position,
    StorySize? size,
    double? rotation,
    double? scale,
    bool? flipHorizontal,
    bool? flipVertical,
  }) {
    return StoryTransform(
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryTransform &&
      other.position == position &&
      other.size == size &&
      other.rotation == rotation &&
      other.scale == scale &&
      other.flipHorizontal == flipHorizontal &&
      other.flipVertical == flipVertical;

  @override
  int get hashCode => Object.hash(
      position, size, rotation, scale, flipHorizontal, flipVertical);

  @override
  String toString() =>
      'StoryTransform(center: $position, size: $size, rotation: $rotation, '
      'scale: $scale)';
}
