import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../composition/document/story_background.dart';
import '../composition/document/story_document.dart';
import '../composition/elements/element_styles.dart';
import '../composition/elements/story_element.dart';
import '../composition/items/story_item.dart';
import '../core/models/story_source.dart';
import '../rendering/contracts/story_element_renderer.dart';
import '../rendering/options/story_render_options.dart';
import '../rendering/registry/story_renderer_registry.dart';
import '../rendering/widgets/story_item_view.dart';

/// Renders story items to images offscreen, with the same renderers as the
/// viewer and editor (in [StoryRenderMode.export]).
///
/// Images referenced by the item are loaded before capturing, so exports
/// never contain loading placeholders. Requires an initialized
/// `WidgetsBinding`.
final class StoryItemSnapshotter {
  /// Creates a snapshotter.
  StoryItemSnapshotter({
    StoryRendererRegistry? renderers,
    this.options = const StoryRenderOptions(),
  }) : renderers = renderers ?? StoryRendererRegistry.withDefaults();

  /// Renderers used for export.
  final StoryRendererRegistry renderers;

  /// Rendering options (image resolver, error reporting).
  final StoryRenderOptions options;

  /// Renders [item] to an image [width] pixels wide. The caller owns and
  /// must dispose the image.
  Future<ui.Image> capture(StoryDocument document, StoryItem item,
      {required int width}) async {
    await _loadImages(document, item);
    final canvas = document.canvas;
    final logical = Size(canvas.width, canvas.height);
    final pixelRatio = width / canvas.width;
    final view = WidgetsBinding.instance.platformDispatcher.implicitView ??
        WidgetsBinding.instance.platformDispatcher.views.first;

    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(child: boundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logical),
      ),
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final focus = FocusManager();
    final buildOwner = BuildOwner(focusManager: focus);
    try {
      final root = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: MediaQuery(
          data: MediaQueryData(size: logical),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.fromSize(
              size: logical,
              child: StoryItemView(
                document: document,
                item: item,
                registry: renderers,
                options: options,
                mode: StoryRenderMode.export,
              ),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);
      // Two passes: the first lets image streams deliver cached frames.
      for (var pass = 0; pass < 2; pass++) {
        buildOwner
          ..buildScope(root)
          ..finalizeTree();
        pipeline
          ..flushLayout()
          ..flushCompositingBits()
          ..flushPaint();
        if (pass == 0) await Future<void>.delayed(Duration.zero);
      }
      return await boundary.toImage(pixelRatio: pixelRatio);
    } finally {
      focus.dispose();
    }
  }

  /// Every image source the item shows.
  static List<StorySource> imageSources(StoryItem item) => [
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

  Future<void> _loadImages(StoryDocument document, StoryItem item) async {
    final sources = [
      ...imageSources(item),
      if (item.background == null)
        if (document.canvas.background case StoryMediaBackground(:final source))
          source,
    ];
    await Future.wait([
      for (final source in sources) _load(document, source),
    ]);
  }

  Future<void> _load(StoryDocument document, StorySource source) {
    final ImageProvider? provider;
    try {
      provider = options.imageResolver.resolve(document.resolveSource(source));
    } on Object {
      return Future.value();
    }
    if (provider == null) return Future.value();
    final done = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    ImageStreamListener? listener;
    void finish() {
      if (!done.isCompleted) done.complete();
      final registered = listener;
      if (registered != null) stream.removeListener(registered);
    }

    // Failures render as error states; the export still succeeds.
    final created = ImageStreamListener(
      (image, sync) => finish(),
      onError: (error, stack) => finish(),
    );
    listener = created;
    stream.addListener(created);
    return done.future;
  }
}
