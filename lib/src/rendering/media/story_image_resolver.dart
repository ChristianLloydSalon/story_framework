import 'package:flutter/widgets.dart';

import '../../core/models/story_source.dart';
import 'file_image_stub.dart' if (dart.library.io) 'file_image_io.dart';

/// Turns a [StorySource] into an [ImageProvider].
///
/// Inject a custom resolver to add caching, authentication, or support for
/// [CustomStorySource]s.
abstract interface class StoryImageResolver {
  /// Returns a provider for [source], or `null` if it cannot be loaded as an
  /// image. [source] has already had asset references resolved.
  ImageProvider? resolve(StorySource source);
}

/// Resolves a [CustomStorySource] to an image provider.
typedef StoryCustomImageResolver = ImageProvider? Function(
    CustomStorySource source);

/// Supplies HTTP headers (for example authorization) for an image URL.
typedef StoryImageHeaders = Map<String, String>? Function(Uri url);

/// The default resolver, built on Flutter's standard image providers.
///
/// | Source | Provider |
/// |---|---|
/// | [NetworkStorySource] | `NetworkImage`, with headers from [headersFor] |
/// | [FileStorySource] | `FileImage` (not available on the web) |
/// | [AssetStorySource] | `AssetImage` |
/// | [MemoryStorySource] | `MemoryImage` |
/// | [CustomStorySource] | [customResolvers] by type |
/// | [StreamStorySource], [ReferenceStorySource] | unsupported (`null`) |
final class DefaultStoryImageResolver implements StoryImageResolver {
  /// Creates the default resolver.
  const DefaultStoryImageResolver({
    this.headersFor,
    this.customResolvers = const {},
  });

  /// HTTP headers for network images. Credentials stay in the app, never in
  /// the document.
  final StoryImageHeaders? headersFor;

  /// Resolvers for [CustomStorySource]s, keyed by [CustomStorySource.type].
  final Map<String, StoryCustomImageResolver> customResolvers;

  @override
  ImageProvider? resolve(StorySource source) {
    return switch (source) {
      NetworkStorySource(:final url) =>
        NetworkImage(url.toString(), headers: headersFor?.call(url)),
      FileStorySource(:final path) => fileImage(path),
      AssetStorySource(:final name, :final package) =>
        AssetImage(name, package: package),
      MemoryStorySource(:final bytes) => MemoryImage(bytes),
      CustomStorySource() => customResolvers[source.type]?.call(source),
      StreamStorySource() || ReferenceStorySource() => null,
    };
  }
}
