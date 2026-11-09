import 'package:collection/collection.dart';

/// A JSON object: string keys mapped to JSON-compatible values.
typedef JsonMap = Map<String, Object?>;

const DeepCollectionEquality _deepEquality = DeepCollectionEquality();

/// Deep structural equality for lists, maps, sets, and plain values.
bool deepEquals(Object? a, Object? b) => _deepEquality.equals(a, b);

/// Deep structural hash, consistent with [deepEquals].
int deepHash(Object? value) => _deepEquality.hash(value);

/// Whether [value] can be encoded as JSON without custom conversion.
///
/// Allowed values are `null`, [bool], finite [num], [String], [List]s of
/// allowed values, and [Map]s with [String] keys and allowed values.
bool isJsonCompatible(Object? value) {
  return switch (value) {
    null || bool() || String() => true,
    num() => value.isFinite,
    List<Object?>() => value.every(isJsonCompatible),
    Map<Object?, Object?>() =>
      value.entries.every((e) => e.key is String && isJsonCompatible(e.value)),
    _ => false,
  };
}

/// Returns a deeply unmodifiable copy of [map].
///
/// Throws an [ArgumentError] when [map] contains values that are not
/// JSON-compatible (see [isJsonCompatible]). Metadata and custom data are part
/// of the serialized document, so they must be JSON-compatible.
JsonMap freezeJsonMap(Map<String, Object?> map, {String name = 'map'}) {
  if (map.isEmpty) return const {};
  if (!isJsonCompatible(map)) {
    throw ArgumentError.value(map, name, 'must contain only JSON values');
  }
  return _freeze(map) as JsonMap;
}

Object? _freeze(Object? value) {
  return switch (value) {
    List<Object?>() => List<Object?>.unmodifiable(value.map(_freeze)),
    Map<Object?, Object?>() => Map<String, Object?>.unmodifiable({
        for (final entry in value.entries)
          entry.key as String: _freeze(entry.value),
      }),
    _ => value,
  };
}
