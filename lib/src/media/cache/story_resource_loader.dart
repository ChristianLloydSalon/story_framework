import 'dart:async';
import 'dart:typed_data';

import '../../core/errors/story_exceptions.dart';
import 'story_cache.dart';

/// Lets a caller abandon an operation.
final class StoryCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Cancels the operation. Calling it again has no effect.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// Downloads the bytes for [key]. Implementations should stop early when
/// [token] is cancelled.
typedef StoryByteFetcher = Future<Uint8List> Function(
    String key, StoryCancellationToken token);

/// Loads media bytes through a cache, sharing concurrent requests.
///
/// - **Cache first:** fresh cached bytes are returned without fetching.
/// - **Deduplication:** concurrent loads of the same key share one fetch.
/// - **Cancellation:** a caller that cancels stops waiting immediately; the
///   fetch itself is cancelled once every waiting caller has cancelled.
/// - **Failures are not cached:** the next load tries again.
/// - **Bounded concurrency:** at most [maxConcurrentFetches] fetches run at
///   once; others wait in order.
final class StoryResourceLoader {
  /// Creates a loader that fetches with [fetcher] and caches in [cache].
  StoryResourceLoader({
    required this.fetcher,
    StoryCacheProvider? cache,
    this.maxConcurrentFetches = 4,
  })  : assert(maxConcurrentFetches > 0, 'must allow at least one fetch'),
        cache = cache ?? MemoryStoryCache();

  /// Downloads bytes.
  final StoryByteFetcher fetcher;

  /// Stores downloaded bytes.
  final StoryCacheProvider cache;

  /// Largest number of fetches running at once.
  final int maxConcurrentFetches;

  final Map<String, _Request> _inFlight = {};
  final List<Completer<void>> _queue = [];
  int _running = 0;

  /// Number of fetches currently shared by callers (for diagnostics).
  int get inFlightCount => _inFlight.length;

  /// The bytes for [key], from the cache or a (shared) fetch.
  ///
  /// Throws a [StoryCancelledException] if [token] is cancelled first.
  Future<Uint8List> load(String key, {StoryCancellationToken? token}) async {
    if (token?.isCancelled ?? false) throw const StoryCancelledException();
    final cached = await cache.read(key);
    if (cached != null) return cached;

    final request = _inFlight[key] ??= _start(key);
    request.waiters++;
    final cancelled = token?.whenCancelled;
    try {
      if (cancelled == null) return await request.future;
      return await Future.any([
        request.future,
        cancelled.then<Uint8List>((_) => throw const StoryCancelledException()),
      ]);
    } finally {
      request.waiters--;
      if (request.waiters == 0 && !request.done) request.token.cancel();
    }
  }

  _Request _start(String key) {
    final request = _Request();
    request.future = _fetch(key, request);
    // Errors reach callers through [load]; avoid unhandled-error reports when
    // every caller has already stopped waiting.
    unawaited(request.future.then<void>((_) {}, onError: (Object _) {}));
    return request;
  }

  Future<Uint8List> _fetch(String key, _Request request) async {
    try {
      await _acquireSlot();
      try {
        if (request.token.isCancelled) {
          throw const StoryCancelledException();
        }
        final bytes = await fetcher(key, request.token);
        if (request.token.isCancelled) {
          throw const StoryCancelledException();
        }
        await cache.write(key, bytes);
        return bytes;
      } finally {
        _releaseSlot();
      }
    } finally {
      request.done = true;
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  Future<void> _acquireSlot() async {
    if (_running < maxConcurrentFetches) {
      _running++;
      return;
    }
    final slot = Completer<void>();
    _queue.add(slot);
    await slot.future;
  }

  void _releaseSlot() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _running--;
    }
  }
}

final class _Request {
  final StoryCancellationToken token = StoryCancellationToken();
  Future<Uint8List> future = Future.value(Uint8List(0));
  int waiters = 0;
  bool done = false;
}
