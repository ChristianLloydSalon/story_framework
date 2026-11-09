@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/media.dart';

void main() {
  test('the web fetcher downloads bytes with fetch', () async {
    final fetch = createStoryHttpFetcher();
    final bytes = await fetch(
        'data:application/octet-stream;base64,AQID', StoryCancellationToken());
    expect(bytes, [1, 2, 3]);
  });

  test('cancelling aborts the request', () async {
    final fetch = createStoryHttpFetcher();
    final token = StoryCancellationToken()..cancel();
    await expectLater(
      fetch('data:application/octet-stream;base64,AQID', token),
      throwsA(isA<StoryCancelledException>()),
    );
  });

  test('failures become cache exceptions', () async {
    final fetch = createStoryHttpFetcher();
    await expectLater(
      fetch('http://invalid.invalid/missing.png', StoryCancellationToken()),
      throwsA(isA<CacheException>()),
    );
  });
}
