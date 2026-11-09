import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/media.dart';

Uint8List bytes(int length) => Uint8List(length);

void main() {
  group('MemoryStoryCache', () {
    test('evicts least recently used entries by size and count', () async {
      final cache = MemoryStoryCache(maxBytes: 10, maxEntries: 3);
      await cache.write('a', bytes(4));
      await cache.write('b', bytes(4));
      await cache.read('a'); // a is now most recent
      await cache.write('c', bytes(4)); // over 10 bytes: evict b
      expect(await cache.exists('a'), isTrue);
      expect(await cache.exists('b'), isFalse);
      expect(cache.sizeInBytes, 8);

      await cache.write('d', bytes(1));
      await cache.write('e', bytes(1)); // 4 entries > 3: evict a
      expect(await cache.exists('a'), isFalse);
      expect(cache.length, 3);
    });

    test('skips entries larger than the whole cache', () async {
      final cache = MemoryStoryCache(maxBytes: 10);
      await cache.write('huge', bytes(11));
      expect(cache.length, 0);
    });

    test('expires entries after the time to live', () async {
      var now = DateTime(2026);
      final cache = MemoryStoryCache(
          timeToLive: const Duration(minutes: 5), now: () => now);
      await cache.write('a', bytes(1));
      now = now.add(const Duration(minutes: 4));
      expect(await cache.read('a'), isNotNull);
      now = now.add(const Duration(minutes: 2));
      expect(await cache.read('a'), isNull);
      expect(cache.sizeInBytes, 0);
    });

    test('remove and clear', () async {
      final cache = MemoryStoryCache();
      await cache.write('a', bytes(2));
      await cache.write('b', bytes(2));
      await cache.remove('a');
      expect(cache.sizeInBytes, 2);
      await cache.clear();
      expect(cache.length, 0);
    });
  });

  group('StoryResourceLoader', () {
    test('shares concurrent requests and caches the result', () async {
      var fetches = 0;
      final gate = Completer<void>();
      final loader = StoryResourceLoader(fetcher: (key, token) async {
        fetches++;
        await gate.future;
        return bytes(3);
      });
      final first = loader.load('u');
      final second = loader.load('u');
      await Future<void>.delayed(Duration.zero);
      expect(loader.inFlightCount, 1);
      gate.complete();
      expect((await first).length, 3);
      expect((await second).length, 3);
      await loader.load('u');
      expect(fetches, 1, reason: 'one shared fetch, then cached');
    });

    test('failures reach every caller and are not cached', () async {
      var attempt = 0;
      final loader = StoryResourceLoader(fetcher: (key, token) async {
        attempt++;
        if (attempt == 1) throw const CacheException('offline');
        return bytes(1);
      });
      await expectLater(loader.load('u'), throwsA(isA<CacheException>()));
      expect((await loader.load('u')).length, 1);
    });

    test('a cancelled caller stops waiting; the fetch stops when nobody waits',
        () async {
      final gate = Completer<void>();
      StoryCancellationToken? fetchToken;
      final loader = StoryResourceLoader(fetcher: (key, token) async {
        fetchToken = token;
        await gate.future;
        return bytes(1);
      });
      final staying = loader.load('u');
      final leavingToken = StoryCancellationToken();
      final leaving = loader.load('u', token: leavingToken);
      await Future<void>.delayed(Duration.zero);
      leavingToken.cancel();
      await expectLater(leaving, throwsA(isA<StoryCancelledException>()));
      expect(fetchToken?.isCancelled, isFalse, reason: 'one caller remains');
      gate.complete();
      expect((await staying).length, 1);

      final lone = StoryCancellationToken();
      final gate2 = Completer<void>();
      final loader2 = StoryResourceLoader(fetcher: (key, token) async {
        fetchToken = token;
        await gate2.future;
        return bytes(1);
      });
      final only = loader2.load('v', token: lone);
      await Future<void>.delayed(Duration.zero);
      lone.cancel();
      await expectLater(only, throwsA(isA<StoryCancelledException>()));
      expect(fetchToken?.isCancelled, isTrue);
      gate2.complete();
    });

    test('limits concurrent fetches', () async {
      var running = 0;
      var peak = 0;
      final loader = StoryResourceLoader(
        maxConcurrentFetches: 2,
        fetcher: (key, token) async {
          running++;
          peak = running > peak ? running : peak;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return bytes(1);
        },
      );
      await Future.wait([for (var i = 0; i < 6; i++) loader.load('k$i')]);
      expect(peak, 2);
    });
  });
}
