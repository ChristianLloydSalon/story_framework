import '../../core/errors/story_exceptions.dart';
import '../../core/utilities/json.dart';

/// Typed, path-aware access to a decoded JSON object.
///
/// Every failure throws a [SerializationException] whose `path` points at the
/// offending value, such as `groups[0].items[3].duration.ms`.
final class JsonReader {
  /// Wraps [json], located at [path] in the document.
  JsonReader(this.json, this.path);

  /// Wraps a root value, which must be a JSON object.
  factory JsonReader.root(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const SerializationException('Expected a JSON object', path: r'$');
    }
    return JsonReader(value, '');
  }

  /// The wrapped object.
  final JsonMap json;

  /// Location of [json] in the document; empty for the root.
  final String path;

  /// The path of [key] inside this object.
  String pathOf(String key) => path.isEmpty ? key : '$path.$key';

  /// Throws a [SerializationException] for [key].
  Never fail(String key, String message) =>
      throw SerializationException(message, path: pathOf(key));

  /// Whether [key] is present with a non-null value.
  bool has(String key) => json[key] != null;

  T? _optional<T extends Object>(String key, String expected) {
    final value = json[key];
    if (value == null) return null;
    if (value is! T) fail(key, 'Expected $expected, got ${value.runtimeType}');
    return value;
  }

  /// A required string.
  String string(String key) =>
      optionalString(key) ?? fail(key, 'Missing required string');

  /// An optional string.
  String? optionalString(String key) => _optional<String>(key, 'a string');

  /// A finite number, or [fallback] when absent.
  double number(String key, {double? fallback}) {
    final value = _optional<num>(key, 'a number');
    if (value == null) {
      return fallback ?? fail(key, 'Missing required number');
    }
    if (!value.isFinite) fail(key, 'Expected a finite number');
    return value.toDouble();
  }

  /// An optional finite number.
  double? optionalNumber(String key) => has(key) ? number(key) : null;

  /// An integer, or [fallback] when absent.
  int integer(String key, {int? fallback}) {
    final value = _optional<num>(key, 'an integer');
    if (value == null) {
      return fallback ?? fail(key, 'Missing required integer');
    }
    if (value is int) return value;
    if (value.isFinite && value == value.roundToDouble()) return value.toInt();
    fail(key, 'Expected an integer, got $value');
  }

  /// An optional integer.
  int? optionalInteger(String key) => has(key) ? integer(key) : null;

  /// A boolean, or [fallback] when absent.
  bool boolean(String key, {required bool fallback}) =>
      _optional<bool>(key, 'a boolean') ?? fallback;

  /// An optional duration stored as integer milliseconds.
  Duration? optionalDuration(String key) {
    final ms = optionalInteger(key);
    return ms == null ? null : Duration(milliseconds: ms);
  }

  /// A duration stored as integer milliseconds, or [fallback] when absent.
  Duration duration(String key, {Duration? fallback}) =>
      optionalDuration(key) ?? fallback ?? fail(key, 'Missing duration');

  /// An optional ISO-8601 timestamp.
  DateTime? optionalDateTime(String key) {
    final value = optionalString(key);
    if (value == null) return null;
    return DateTime.tryParse(value) ??
        fail(key, 'Expected an ISO-8601 timestamp, got "$value"');
  }

  /// An enum value stored by name, or [fallback] when absent.
  E enumValue<E extends Enum>(String key, List<E> values, E fallback) {
    final name = optionalString(key);
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    fail(
        key,
        'Unknown value "$name"; expected one of '
        '${values.map((v) => v.name).join(', ')}');
  }

  /// A JSON object stored as-is, or an empty map when absent.
  JsonMap map(String key) =>
      _optional<Map<String, Object?>>(key, 'an object') ?? const {};

  /// A required nested object.
  JsonReader child(String key) =>
      optionalChild(key) ?? fail(key, 'Missing required object');

  /// An optional nested object.
  JsonReader? optionalChild(String key) {
    final value = _optional<Map<String, Object?>>(key, 'an object');
    return value == null ? null : JsonReader(value, pathOf(key));
  }

  /// A list of raw values, or an empty list when absent.
  List<Object?> list(String key) =>
      _optional<List<Object?>>(key, 'a list') ?? const [];

  /// A list of nested objects, or an empty list when absent.
  List<JsonReader> children(String key) {
    final values = list(key);
    return [
      for (var i = 0; i < values.length; i++)
        switch (values[i]) {
          final Map<String, Object?> value =>
            JsonReader(value, '${pathOf(key)}[$i]'),
          final other => throw SerializationException(
              'Expected an object, got ${other.runtimeType}',
              path: '${pathOf(key)}[$i]',
            ),
        },
    ];
  }

  /// A list of finite numbers.
  List<double> numbers(String key) {
    final values = list(key);
    return [
      for (var i = 0; i < values.length; i++)
        switch (values[i]) {
          final num value when value.isFinite => value.toDouble(),
          _ => throw SerializationException('Expected a finite number',
              path: '${pathOf(key)}[$i]'),
        },
    ];
  }
}
