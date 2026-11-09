import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import '../../core/errors/story_exceptions.dart';
import 'story_resource_loader.dart';

/// Fetches URLs with the browser's `fetch`, adding [headersFor] headers.
///
/// Cancelling a load aborts the request. Servers must allow cross-origin
/// requests (CORS) from the app's origin, as they must for any image the
/// web app loads. The browser's HTTP cache applies as well.
StoryByteFetcher createStoryHttpFetcher({
  Map<String, String>? Function(Uri url)? headersFor,
}) =>
    (key, token) async {
      final url = Uri.parse(key);
      final abort = _AbortController();
      unawaited(token.whenCancelled.then((_) => abort.abort()));
      final headers = headersFor?.call(url);
      try {
        // `fetch` rejects an explicit null for headers, so omit them instead.
        final init = headers == null || headers.isEmpty
            ? _RequestInit(method: 'GET'.toJS, signal: abort.signal)
            : _RequestInit.withHeaders(
                method: 'GET'.toJS,
                headers: headers.jsify(),
                signal: abort.signal,
              );
        final response = await _fetch(key.toJS, init).toDart;
        if (!response.ok) {
          throw CacheException('HTTP ${response.status} for '
              '${url.scheme}://${url.host}${url.path}');
        }
        final buffer = await response.arrayBuffer().toDart;
        if (token.isCancelled) throw const StoryCancelledException();
        return Uint8List.view(buffer.toDart);
      } on StoryException {
        rethrow;
      } on Object catch (error) {
        if (token.isCancelled) throw const StoryCancelledException();
        // Network failures and blocked cross-origin requests land here.
        throw CacheException(
            'Request failed for ${url.scheme}://${url.host}${url.path}: '
            '$error');
      }
    };

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, _RequestInit init);

extension type _RequestInit._(JSObject _) implements JSObject {
  external factory _RequestInit({JSString method, JSObject signal});

  external factory _RequestInit.withHeaders({
    JSString method,
    JSAny? headers,
    JSObject signal,
  });
}

extension type _Response._(JSObject _) implements JSObject {
  external bool get ok;
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSObject get signal;
  external void abort();
}
