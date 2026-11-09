import 'dart:collection';
import 'dart:typed_data';

/// Stores downloaded media bytes by key.
///
/// Inject your own implementation (for example over a disk cache) wherever
/// the framework accepts a cache. [MemoryStoryCache] is the built-in one.
abstract interface class StoryCacheProvider {
  /// Whether a fresh entry exists for [key].
  Future<bool> exists(String key);

  /// The bytes for [key], or `null` when absent or expired.
  Future<Uint8List?> read(String key);

  /// Stores [bytes] under [key].
  Future<void> write(String key, Uint8List bytes);

  /// Removes [key].
  Future<void> remove(String key);

  /// Removes everything.
  Future<void> clear();
}

/// A bounded in-memory cache with least-recently-used eviction and an
/// optional time to live.
///
/// Both the total size ([maxBytes]) and the entry count ([maxEntries]) are
/// bounded; the least recently read or written entries go first. Entries
/// larger than [maxBytes] are not cached at all.
final class MemoryStoryCache implements StoryCacheProvider {
  /// Creates a cache.
  MemoryStoryCache({
    this.maxBytes = 64 * 1024 * 1024,
    this.maxEntries = 256,
    this.timeToLive,
    DateTime Function()? now,
  })  : assert(maxBytes > 0 && maxEntries > 0, 'limits must be positive'),
        _now = now ?? DateTime.now;

  /// Largest total size, in bytes.
  final int maxBytes;

  /// Largest number of entries.
  final int maxEntries;

  /// How long an entry stays fresh, or `null` for no expiry.
  final Duration? timeToLive;

  final DateTime Function() _now;

  // Insertion order doubles as recency order: reads and writes move entries
  // to the end, eviction takes from the front.
  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap();
  int _bytes = 0;

  /// Current total size, in bytes.
  int get sizeInBytes => _bytes;

  /// Current number of entries.
  int get length => _entries.length;

  _Entry? _fresh(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    final ttl = timeToLive;
    if (ttl != null && _now().difference(entry.storedAt) > ttl) {
      _drop(key);
      return null;
    }
    return entry;
  }

  @override
  Future<bool> exists(String key) async => _fresh(key) != null;

  @override
  Future<Uint8List?> read(String key) async {
    final entry = _fresh(key);
    if (entry == null) return null;
    _entries
      ..remove(key)
      ..[key] = entry;
    return entry.bytes;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    _drop(key);
    if (bytes.lengthInBytes > maxBytes) return;
    _entries[key] = _Entry(bytes, _now());
    _bytes += bytes.lengthInBytes;
    while (_bytes > maxBytes || _entries.length > maxEntries) {
      _drop(_entries.keys.first);
    }
  }

  @override
  Future<void> remove(String key) async => _drop(key);

  @override
  Future<void> clear() async {
    _entries.clear();
    _bytes = 0;
  }

  void _drop(String key) {
    final removed = _entries.remove(key);
    if (removed != null) _bytes -= removed.bytes.lengthInBytes;
  }
}

final class _Entry {
  _Entry(this.bytes, this.storedAt);

  final Uint8List bytes;
  final DateTime storedAt;
}
