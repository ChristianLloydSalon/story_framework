import 'package:flutter/widgets.dart';

import '../../composition/elements/story_element.dart';
import '../media/story_image_resolver.dart';

/// Builds the placeholder shown while [element] loads.
typedef StoryLoadingBuilder = Widget Function(
    BuildContext context, StoryElement element);

/// Builds the widget shown when [element] fails to render.
typedef StoryErrorBuilder = Widget Function(
    BuildContext context, StoryElement element, Object error);

/// Builds the widget shown for an element no renderer supports.
typedef StoryUnsupportedBuilder = Widget Function(
    BuildContext context, StoryElement element);

/// Receives rendering failures, including elements without a renderer.
typedef StoryRenderErrorCallback = void Function(
    StoryElement element, Object error, StackTrace? stack);

/// Options shared by every renderer while rendering a composition.
@immutable
final class StoryRenderOptions {
  /// Creates rendering options.
  const StoryRenderOptions({
    this.imageResolver = const DefaultStoryImageResolver(),
    this.loadingBuilder,
    this.errorBuilder,
    this.unsupportedBuilder,
    this.onError,
    this.textScaler = TextScaler.noScaling,
  });

  /// Turns image sources into image providers.
  final StoryImageResolver imageResolver;

  /// Placeholder while content loads. Defaults to an empty box, so the
  /// background shows through.
  final StoryLoadingBuilder? loadingBuilder;

  /// Replacement for content that failed. Defaults to a translucent box.
  final StoryErrorBuilder? errorBuilder;

  /// Replacement for elements without a renderer. Defaults to nothing.
  final StoryUnsupportedBuilder? unsupportedBuilder;

  /// Receives failures. Defaults to [FlutterError.reportError], so problems are
  /// never silently swallowed.
  final StoryRenderErrorCallback? onError;

  /// Scaling applied to text inside the canvas.
  ///
  /// Defaults to [TextScaler.noScaling]: text is sized in canvas units, so it
  /// already scales with the canvas, and platform text scaling would push it
  /// out of its designed box. Pass `MediaQuery.textScalerOf(context)` to honor
  /// the user's accessibility setting instead.
  final TextScaler textScaler;

  /// Reports [error] for [element] through [onError] or
  /// [FlutterError.reportError].
  void reportError(StoryElement element, Object error, [StackTrace? stack]) {
    final callback = onError;
    if (callback != null) {
      callback(element, error, stack);
      return;
    }
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'story_framework',
      context: ErrorDescription(
          'while rendering ${element.type} element "${element.id}"'),
    ));
  }

  /// Returns a copy with the given fields replaced.
  StoryRenderOptions copyWith({
    StoryImageResolver? imageResolver,
    StoryLoadingBuilder? loadingBuilder,
    StoryErrorBuilder? errorBuilder,
    StoryUnsupportedBuilder? unsupportedBuilder,
    StoryRenderErrorCallback? onError,
    TextScaler? textScaler,
  }) {
    return StoryRenderOptions(
      imageResolver: imageResolver ?? this.imageResolver,
      loadingBuilder: loadingBuilder ?? this.loadingBuilder,
      errorBuilder: errorBuilder ?? this.errorBuilder,
      unsupportedBuilder: unsupportedBuilder ?? this.unsupportedBuilder,
      onError: onError ?? this.onError,
      textScaler: textScaler ?? this.textScaler,
    );
  }
}
