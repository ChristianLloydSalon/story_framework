import 'package:flutter/widgets.dart';

import '../../composition/document/story_background.dart';
import '../../composition/document/story_document.dart';
import '../../composition/items/story_item.dart';
import '../../core/enums/story_enums.dart';
import '../../core/errors/story_exceptions.dart';
import '../../core/models/story_source.dart';
import '../contracts/story_element_renderer.dart';
import '../conversions.dart';
import '../options/story_render_options.dart';
import '../registry/story_renderer_registry.dart';

/// Renders one [StoryItem] on its document's canvas, scaled to fit.
///
/// Elements are laid out in canvas units inside a canvas-sized box, which is
/// then scaled to the available space with the canvas `scalingBehavior`. The
/// same item therefore looks identical on every screen, in the viewer, the
/// editor, and exports.
///
/// When [registry] is `null`, the view creates a registry with the built-in
/// renderers and disposes it with itself. Pass a shared registry to add custom
/// renderers; its owner disposes it.
class StoryItemView extends StatefulWidget {
  /// Creates a view of [item] from [document].
  const StoryItemView({
    required this.document,
    required this.item,
    this.registry,
    this.options = const StoryRenderOptions(),
    this.mode = StoryRenderMode.viewer,
    super.key,
  });

  /// The document that contains [item] (for its canvas and assets).
  final StoryDocument document;

  /// The item to render.
  final StoryItem item;

  /// Renderers to use, or `null` for the built-in ones.
  final StoryRendererRegistry? registry;

  /// Shared rendering options.
  final StoryRenderOptions options;

  /// Where the item is being rendered.
  final StoryRenderMode mode;

  @override
  State<StoryItemView> createState() => _StoryItemViewState();
}

class _StoryItemViewState extends State<StoryItemView> {
  StoryRendererRegistry? _ownedRegistry;

  StoryRendererRegistry get _registry =>
      widget.registry ??
      (_ownedRegistry ??= StoryRendererRegistry.withDefaults());

  @override
  void didUpdateWidget(StoryItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final owned = _ownedRegistry;
    if (widget.registry != null && owned != null) {
      owned.dispose();
      _ownedRegistry = null;
    }
  }

  @override
  void dispose() {
    _ownedRegistry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = widget.document.canvas;
    final registry = _registry;
    final surface = SizedBox(
      width: canvas.width,
      height: canvas.height,
      child: ListenableBuilder(
        listenable: registry,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(
              child: StoryBackgroundView(
                background: widget.item.background ?? canvas.background,
                document: widget.document,
                options: widget.options,
              ),
            ),
            for (final element in widget.item.elementsInPaintOrder)
              if (element.visible)
                StoryElementView(
                  key: ValueKey(element.id),
                  registry: registry,
                  renderContext: StoryRenderContext(
                    element: element,
                    item: widget.item,
                    document: widget.document,
                    mode: widget.mode,
                    options: widget.options,
                  ),
                ),
          ],
        ),
      ),
    );

    final fitted = ClipRect(
      child: FittedBox(
        fit: canvas.scalingBehavior.toBoxFit(),
        child: surface,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.hasBoundedWidth && constraints.hasBoundedHeight
              ? SizedBox.expand(child: fitted)
              : AspectRatio(aspectRatio: canvas.aspectRatio, child: fitted),
    );
  }
}

/// Places one element in a canvas-sized [Stack] and renders it.
///
/// Applies the element transform (center position, size, rotation, scale,
/// flips), opacity, and semantics label, then delegates the content to the
/// renderer from [registry]. Elements without a renderer are shown with
/// [StoryRenderOptions.unsupportedBuilder] and reported once.
class StoryElementView extends StatelessWidget {
  /// Creates an element view. Must be a direct child of a [Stack].
  const StoryElementView({
    required this.registry,
    required this.renderContext,
    super.key,
  });

  /// Source of the element's renderer.
  final StoryRendererRegistry registry;

  /// The element and its surroundings.
  final StoryRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    final element = renderContext.element;
    final transform = element.transform;
    final size = transform.size;

    final renderer = registry.rendererFor(element);
    Widget content = renderer == null
        ? _UnsupportedElement(renderContext: renderContext)
        : renderer.build(context, renderContext);

    content = SizedBox(width: size.width, height: size.height, child: content);

    final label = element.semanticLabel;
    if (label != null) {
      content = Semantics(
        label: label,
        container: true,
        child: ExcludeSemantics(child: content),
      );
    }

    final scaleX =
        transform.flipHorizontal ? -transform.scale : transform.scale;
    final scaleY = transform.flipVertical ? -transform.scale : transform.scale;
    if (transform.rotation != 0 || scaleX != 1 || scaleY != 1) {
      content = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationZ(transform.rotation)
          ..multiply(Matrix4.diagonal3Values(scaleX, scaleY, 1)),
        child: content,
      );
    }

    if (element.opacity < 1) {
      content =
          Opacity(opacity: element.opacity.clamp(0.0, 1.0), child: content);
    }

    return Positioned(
      left: transform.position.x - size.width / 2,
      top: transform.position.y - size.height / 2,
      width: size.width,
      height: size.height,
      child: content,
    );
  }
}

/// Shown for an element no renderer supports; reports it once per element.
class _UnsupportedElement extends StatefulWidget {
  const _UnsupportedElement({required this.renderContext});

  final StoryRenderContext renderContext;

  @override
  State<_UnsupportedElement> createState() => _UnsupportedElementState();
}

class _UnsupportedElementState extends State<_UnsupportedElement> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(_UnsupportedElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
        oldWidget.renderContext.element, widget.renderContext.element)) {
      _report();
    }
  }

  void _report() {
    final element = widget.renderContext.element;
    final options = widget.renderContext.options;
    final error = RendererNotRegisteredException(element.type,
        'No renderer supports ${element.type} element "${element.id}"');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => options.reportError(element, error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderContext = widget.renderContext;
    final builder = renderContext.options.unsupportedBuilder;
    return builder == null
        ? const SizedBox.shrink()
        : builder(context, renderContext.element);
  }
}

/// Paints a [StoryBackground] filling its box.
class StoryBackgroundView extends StatelessWidget {
  /// Creates a background view.
  const StoryBackgroundView({
    required this.background,
    required this.document,
    this.options = const StoryRenderOptions(),
    super.key,
  });

  /// What to paint.
  final StoryBackground background;

  /// Used to resolve asset references in media backgrounds.
  final StoryDocument document;

  /// Supplies the image resolver.
  final StoryRenderOptions options;

  @override
  Widget build(BuildContext context) {
    return switch (background) {
      StoryColorBackground(:final color) => ColoredBox(color: color.toColor()),
      StoryGradientBackground(
        :final colors,
        :final stops,
        :final begin,
        :final end
      ) =>
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [for (final c in colors) c.toColor()],
              stops: stops,
              begin: begin.toAlignment(),
              end: end.toAlignment(),
            ),
          ),
        ),
      StoryMediaBackground(:final source, :final fit) => _MediaBackground(
          source: source,
          fit: fit,
          document: document,
          options: options,
        ),
    };
  }
}

/// An image background.
class _MediaBackground extends StatelessWidget {
  const _MediaBackground({
    required this.source,
    required this.fit,
    required this.document,
    required this.options,
  });

  final StorySource source;
  final StoryFit fit;
  final StoryDocument document;
  final StoryRenderOptions options;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? provider;
    try {
      provider = options.imageResolver.resolve(document.resolveSource(source));
    } on StoryException catch (error, stack) {
      return _BackgroundFailure(error: error, stack: stack);
    }
    if (provider == null) {
      return _BackgroundFailure(
        error: UnsupportedStoryTypeException(
            'Cannot load $source as a background image'),
      );
    }
    // Without an errorBuilder, Flutter reports image failures itself.
    return Image(
      image: provider,
      fit: fit.toBoxFit(),
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }
}

/// An empty background that reports why it is empty, once per mount.
///
/// Media backgrounds have no element to attribute failures to, so they go to
/// Flutter's standard error reporting.
class _BackgroundFailure extends StatefulWidget {
  const _BackgroundFailure({required this.error, this.stack});

  final Object error;
  final StackTrace? stack;

  @override
  State<_BackgroundFailure> createState() => _BackgroundFailureState();
}

class _BackgroundFailureState extends State<_BackgroundFailure> {
  @override
  void initState() {
    super.initState();
    FlutterError.reportError(FlutterErrorDetails(
      exception: widget.error,
      stack: widget.stack,
      library: 'story_framework',
      context: ErrorDescription('while rendering a story background'),
    ));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
