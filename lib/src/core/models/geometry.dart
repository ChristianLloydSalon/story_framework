import 'package:meta/meta.dart';

/// A point in story canvas coordinates.
///
/// Canvas coordinates are logical units with the origin at the top-left
/// corner of the canvas, x growing right and y growing down.
@immutable
final class StoryPoint {
  /// Creates a point at ([x], [y]).
  const StoryPoint(this.x, this.y);

  /// The origin.
  static const StoryPoint zero = StoryPoint(0, 0);

  /// Horizontal coordinate.
  final double x;

  /// Vertical coordinate.
  final double y;

  /// Component-wise addition.
  StoryPoint operator +(StoryPoint other) =>
      StoryPoint(x + other.x, y + other.y);

  /// Component-wise subtraction.
  StoryPoint operator -(StoryPoint other) =>
      StoryPoint(x - other.x, y - other.y);

  /// Multiplies both components by [factor].
  StoryPoint operator *(double factor) => StoryPoint(x * factor, y * factor);

  /// Whether both components are finite.
  bool get isFinite => x.isFinite && y.isFinite;

  @override
  bool operator ==(Object other) =>
      other is StoryPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'StoryPoint($x, $y)';
}

/// A width and height in story canvas units.
@immutable
final class StorySize {
  /// Creates a size.
  const StorySize(this.width, this.height);

  /// A square size with equal sides.
  const StorySize.square(double side)
      : width = side,
        height = side;

  /// The empty size.
  static const StorySize zero = StorySize(0, 0);

  /// Horizontal extent.
  final double width;

  /// Vertical extent.
  final double height;

  /// `width / height`, or `0` when [height] is zero.
  double get aspectRatio => height == 0 ? 0 : width / height;

  /// Whether either dimension is zero or negative.
  bool get isEmpty => width <= 0 || height <= 0;

  /// Whether both dimensions are finite.
  bool get isFinite => width.isFinite && height.isFinite;

  /// Multiplies both dimensions by [factor].
  StorySize operator *(double factor) =>
      StorySize(width * factor, height * factor);

  @override
  bool operator ==(Object other) =>
      other is StorySize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'StorySize($width, $height)';
}

/// An axis-aligned rectangle in story canvas coordinates.
@immutable
final class StoryRect {
  /// Creates a rectangle from its top-left corner and size.
  const StoryRect.fromLTWH(this.left, this.top, this.width, this.height);

  /// Creates a rectangle of [size] centered on [center].
  StoryRect.fromCenter(StoryPoint center, StorySize size)
      : left = center.x - size.width / 2,
        top = center.y - size.height / 2,
        width = size.width,
        height = size.height;

  /// Left edge.
  final double left;

  /// Top edge.
  final double top;

  /// Horizontal extent.
  final double width;

  /// Vertical extent.
  final double height;

  /// Right edge.
  double get right => left + width;

  /// Bottom edge.
  double get bottom => top + height;

  /// The center point.
  StoryPoint get center => StoryPoint(left + width / 2, top + height / 2);

  /// The size.
  StorySize get size => StorySize(width, height);

  /// Whether [point] lies inside this rectangle (edges inclusive).
  bool contains(StoryPoint point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= top &&
      point.y <= bottom;

  /// Whether this rectangle and [other] share any area or edge.
  bool overlaps(StoryRect other) =>
      left <= other.right &&
      other.left <= right &&
      top <= other.bottom &&
      other.top <= bottom;

  /// The smallest rectangle containing this one and [other].
  StoryRect union(StoryRect other) {
    final l = left < other.left ? left : other.left;
    final t = top < other.top ? top : other.top;
    final r = right > other.right ? right : other.right;
    final b = bottom > other.bottom ? bottom : other.bottom;
    return StoryRect.fromLTWH(l, t, r - l, b - t);
  }

  /// The rectangle spanning two corner points, in any order.
  static StoryRect fromPoints(StoryPoint a, StoryPoint b) {
    final l = a.x < b.x ? a.x : b.x;
    final t = a.y < b.y ? a.y : b.y;
    return StoryRect.fromLTWH(l, t, (a.x - b.x).abs(), (a.y - b.y).abs());
  }

  @override
  bool operator ==(Object other) =>
      other is StoryRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'StoryRect.fromLTWH($left, $top, $width, $height)';
}

/// Insets from each edge, in story canvas units.
@immutable
final class StoryInsets {
  /// Creates insets with individual edge values.
  const StoryInsets.only({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  /// Creates insets with the same [value] on every edge.
  const StoryInsets.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  /// No insets.
  static const StoryInsets zero = StoryInsets.only();

  /// Left inset.
  final double left;

  /// Top inset.
  final double top;

  /// Right inset.
  final double right;

  /// Bottom inset.
  final double bottom;

  /// Whether every inset is finite and non-negative.
  bool get isValid =>
      [left, top, right, bottom].every((value) => value.isFinite && value >= 0);

  @override
  bool operator ==(Object other) =>
      other is StoryInsets &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'StoryInsets($left, $top, $right, $bottom)';
}
