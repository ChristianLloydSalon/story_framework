import 'dart:math' as math;

/// Creates ids for new documents, groups, items, and elements.
abstract interface class StoryIdGenerator {
  /// Returns a new id starting with [prefix], such as `text-k3j9x2`.
  String next(String prefix);
}

/// Time-based ids with a random suffix; unique enough for client editing.
final class RandomStoryIdGenerator implements StoryIdGenerator {
  /// Creates a generator; pass [random] for reproducible ids.
  RandomStoryIdGenerator({math.Random? random})
      : _random = random ?? math.Random();

  final math.Random _random;
  static const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

  @override
  String next(String prefix) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix =
        List.generate(4, (_) => _alphabet[_random.nextInt(_alphabet.length)])
            .join();
    return '$prefix-$time$suffix';
  }
}

/// Predictable ids (`text-1`, `text-2`, ...), useful in tests.
final class SequentialStoryIdGenerator implements StoryIdGenerator {
  final Map<String, int> _counters = {};

  @override
  String next(String prefix) {
    final count = (_counters[prefix] ?? 0) + 1;
    _counters[prefix] = count;
    return '$prefix-$count';
  }
}
