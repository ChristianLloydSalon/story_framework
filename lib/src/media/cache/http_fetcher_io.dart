import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/errors/story_exceptions.dart';
import 'story_resource_loader.dart';

/// Fetches URLs with `dart:io`'s [HttpClient], adding [headersFor] headers.
StoryByteFetcher createStoryHttpFetcher({
  Map<String, String>? Function(Uri url)? headersFor,
}) {
  final client = HttpClient();
  return (key, token) async {
    final url = Uri.parse(key);
    final request = await client.getUrl(url);
    headersFor?.call(url)?.forEach(request.headers.set);
    unawaited(token.whenCancelled.then((_) => request.abort()));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw CacheException(
          'HTTP ${response.statusCode} for ${url.scheme}://${url.host}${url.path}');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (token.isCancelled) throw const StoryCancelledException();
      builder.add(chunk);
    }
    return builder.takeBytes();
  };
}
