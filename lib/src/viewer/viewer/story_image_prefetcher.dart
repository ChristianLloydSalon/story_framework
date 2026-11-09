import 'package:flutter/widgets.dart';

import '../../composition/document/story_background.dart';
import '../../composition/elements/element_styles.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/items/story_item.dart';
import '../../core/models/story_source.dart';
import '../../engine/controller/story_controller.dart';
import '../../engine/state/story_selection.dart';
import '../../rendering/options/story_render_options.dart';

/// Decodes the next item's images ahead of time, so they appear instantly.
///
/// Prefetching is bounded to the single upcoming item and runs once per
/// item. Decoded images live in Flutter's `ImageCache`, which bounds memory.
/// Failures are ignored here; they are reported when the item is shown.
class StoryImagePrefetcher extends StatefulWidget {
  /// Creates a prefetcher around [child].
  const StoryImagePrefetcher({
    required this.controller,
    required this.options,
    required this.child,
    super.key,
  });

  /// The playback controller whose upcoming item is prefetched.
  final StoryController controller;

  /// Supplies the image resolver.
  final StoryRenderOptions options;

  /// The viewer content.
  final Widget child;

  /// Every image source [item] shows: image elements, image stickers, video
  /// posters, and media backgrounds.
  static List<StorySource> imageSourcesOf(StoryItem item) => [
        if (item.background case StoryMediaBackground(:final source)) source,
        for (final element in item.elements)
          if (element.visible)
            ...switch (element) {
              ImageElement(:final source) => [source],
              StickerElement(sticker: ImageSticker(:final source)) => [source],
              VideoElement(:final poster?) => [poster],
              _ => const <StorySource>[],
            },
      ];

  @override
  State<StoryImagePrefetcher> createState() => _StoryImagePrefetcherState();
}

class _StoryImagePrefetcherState extends State<StoryImagePrefetcher> {
  StorySelection<(int, int)>? _location;
  String? _prefetchedItemId;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(StoryImagePrefetcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    if (widget.controller.isDisposed) return;
    _location = widget.controller
        .select((state) => (state.groupIndex, state.itemIndex))
      ..addListener(_schedule);
    _schedule();
  }

  void _detach() {
    final location = _location;
    if (location == null) return;
    location
      ..removeListener(_schedule)
      ..dispose();
    _location = null;
  }

  void _schedule() {
    // Prefetch after the frame so the current item renders first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetch());
  }

  void _prefetch() {
    final controller = widget.controller;
    if (!mounted || controller.isDisposed) return;
    final next = controller.upcomingLocation;
    final item = next == null ? null : controller.document.itemAt(next);
    if (item == null || item.id == _prefetchedItemId) return;
    _prefetchedItemId = item.id;
    for (final source in StoryImagePrefetcher.imageSourcesOf(item)) {
      final ImageProvider? provider;
      try {
        provider = widget.options.imageResolver
            .resolve(controller.document.resolveSource(source));
      } on Object {
        continue;
      }
      if (provider == null) continue;
      precacheImage(provider, context, onError: (error, stack) {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
