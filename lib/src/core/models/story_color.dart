import 'package:meta/meta.dart';

/// A 32-bit ARGB color, independent of `dart:ui`.
///
/// Core models avoid Flutter types so they stay serializable and testable in
/// pure Dart. Rendering layers convert to `Color` at the edge.
@immutable
final class StoryColor {
  /// Creates a color from a packed `0xAARRGGBB` value.
  const StoryColor(int value) : value = value & 0xFFFFFFFF;

  /// Creates a color from 8-bit alpha, red, green, and blue channels.
  const StoryColor.fromARGB(int alpha, int red, int green, int blue)
      : value = ((alpha & 0xff) << 24) |
            ((red & 0xff) << 16) |
            ((green & 0xff) << 8) |
            (blue & 0xff);

  /// Opaque black.
  static const StoryColor black = StoryColor(0xFF000000);

  /// Opaque white.
  static const StoryColor white = StoryColor(0xFFFFFFFF);

  /// Fully transparent black.
  static const StoryColor transparent = StoryColor(0x00000000);

  /// The packed `0xAARRGGBB` value.
  final int value;

  /// Alpha channel, 0–255.
  int get alpha => (value >> 24) & 0xff;

  /// Red channel, 0–255.
  int get red => (value >> 16) & 0xff;

  /// Green channel, 0–255.
  int get green => (value >> 8) & 0xff;

  /// Blue channel, 0–255.
  int get blue => value & 0xff;

  /// Alpha as a fraction between 0 and 1.
  double get opacity => alpha / 0xff;

  /// Returns this color with a different [alpha] channel.
  StoryColor withAlpha(int alpha) =>
      StoryColor.fromARGB(alpha, red, green, blue);

  /// The color as an `#AARRGGBB` hex string.
  String toHex() => '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// Parses `#RRGGBB` or `#AARRGGBB` (the `#` is optional).
  ///
  /// Throws a [FormatException] for any other input.
  static StoryColor parse(String hex) {
    final digits = hex.startsWith('#') ? hex.substring(1) : hex;
    final parsed = int.tryParse(digits, radix: 16);
    if (parsed == null || (digits.length != 6 && digits.length != 8)) {
      throw FormatException('Invalid color', hex);
    }
    return StoryColor(digits.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  @override
  bool operator ==(Object other) => other is StoryColor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StoryColor(${toHex()})';
}
