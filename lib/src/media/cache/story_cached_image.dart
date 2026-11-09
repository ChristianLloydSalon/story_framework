import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'story_resource_loader.dart';

export 'http_fetcher_stub.dart' if (dart.library.io) 'http_fetcher_io.dart';

/// An image loaded through a [StoryResourceLoader], so its encoded bytes are
/// cached (surviving `ImageCache` eviction) and concurrent loads of the same
/// URL share one download.
@immutable
final class StoryCachedImageProvider
    extends ImageProvider<StoryCachedImageProvider> {
  /// Creates a provider for [url].
  const StoryCachedImageProvider(this.url,
      {required this.loader, this.scale = 1});

  /// The image URL, also the cache key.
  final String url;

  /// Loads and caches the bytes.
  final StoryResourceLoader loader;

  /// Image scale.
  final double scale;

  @override
  Future<StoryCachedImageProvider> obtainKey(
          ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    StoryCachedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.url,
    );
  }

  static Future<ui.Codec> _load(
    StoryCachedImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.loader.load(key.url);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is StoryCachedImageProvider &&
      other.url == url &&
      identical(other.loader, loader) &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(url, loader, scale);

  @override
  String toString() => 'StoryCachedImageProvider(${Uri.tryParse(url)?.host})';
}
