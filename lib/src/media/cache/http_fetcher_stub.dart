import '../../core/errors/story_exceptions.dart';
import 'story_resource_loader.dart';

/// Without `dart:io` (on the web) there is no built-in fetcher; the browser's
/// own HTTP cache applies. Supply a fetcher to `StoryResourceLoader` instead.
StoryByteFetcher createStoryHttpFetcher({
  Map<String, String>? Function(Uri url)? headersFor,
}) =>
    (key, token) async => throw const UnsupportedStoryTypeException(
        'No built-in HTTP fetcher on this platform; pass your own');
