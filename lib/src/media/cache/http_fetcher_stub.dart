import '../../core/errors/story_exceptions.dart';
import 'story_resource_loader.dart';

/// Used only on platforms with neither `dart:io` nor JavaScript interop.
/// Supply a fetcher to `StoryResourceLoader` there instead.
StoryByteFetcher createStoryHttpFetcher({
  Map<String, String>? Function(Uri url)? headersFor,
}) =>
    (key, token) async => throw const UnsupportedStoryTypeException(
        'No built-in HTTP fetcher on this platform; pass your own');
