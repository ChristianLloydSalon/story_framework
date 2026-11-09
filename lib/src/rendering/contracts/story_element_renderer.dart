import 'package:flutter/widgets.dart';

import '../../composition/document/story_document.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/items/story_item.dart';
import '../../core/models/story_source.dart';
import '../options/story_render_options.dart';

/// Where a composition is being rendered.
///
/// Renderers can adapt to the mode, for example by skipping expensive effects
/// in the editor or waiting for full-resolution media when exporting.
enum StoryRenderMode {
  /// Playback in a story viewer.
  viewer,

  /// Interactive editing.
  editor,

  /// Offscreen rendering for export.
  export,
}

/// Everything a renderer needs to build one element.
@immutable
final class StoryRenderContext {
  /// Creates a render context.
  const StoryRenderContext({
    required this.element,
    required this.item,
    required this.document,
    required this.mode,
    required this.options,
  });

  /// The element being rendered.
  final StoryElement element;

  /// The item that contains [element].
  final StoryItem item;

  /// The document that contains [item].
  final StoryDocument document;

  /// Where the element is being rendered.
  final StoryRenderMode mode;

  /// Shared rendering options.
  final StoryRenderOptions options;

  /// Resolves asset references in [source] (see
  /// [StoryDocument.resolveSource]).
  StorySource resolveSource(StorySource source) =>
      document.resolveSource(source);

  /// An image provider for [source] after resolving asset references, or
  /// `null` when the configured resolver cannot load it.
  ImageProvider? imageProviderFor(StorySource source) =>
      options.imageResolver.resolve(resolveSource(source));
}

/// The placeholder shown while an element's content loads.
///
/// Uses [StoryRenderOptions.loadingBuilder], or an empty box so the
/// background shows through.
class StoryElementLoading extends StatelessWidget {
  /// Creates a loading placeholder for `renderContext.element`.
  const StoryElementLoading({required this.renderContext, super.key});

  /// The element that is loading.
  final StoryRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    final builder = renderContext.options.loadingBuilder;
    return builder == null
        ? const SizedBox.expand()
        : builder(context, renderContext.element);
  }
}

/// Shown in place of an element whose content failed.
///
/// Uses [StoryRenderOptions.errorBuilder], or a translucent box. The error is
/// reported through [StoryRenderOptions.onError] once per mount (and again
/// only if the error changes), after the frame, so callbacks may safely call
/// `setState`.
class StoryElementError extends StatefulWidget {
  /// Creates an error view for `renderContext.element`.
  const StoryElementError({
    required this.renderContext,
    required this.error,
    this.stack,
    super.key,
  });

  /// The element that failed.
  final StoryRenderContext renderContext;

  /// The failure.
  final Object error;

  /// Where the failure happened, if known.
  final StackTrace? stack;

  @override
  State<StoryElementError> createState() => _StoryElementErrorState();
}

class _StoryElementErrorState extends State<StoryElementError> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(StoryElementError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != widget.error) _report();
  }

  void _report() {
    final StoryElementError(:renderContext, :error, :stack) = widget;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => renderContext.options
          .reportError(renderContext.element, error, stack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderContext = widget.renderContext;
    final builder = renderContext.options.errorBuilder;
    return builder == null
        ? const SizedBox.expand(child: ColoredBox(color: Color(0x33FFFFFF)))
        : builder(context, renderContext.element, widget.error);
  }
}

/// Turns one kind of [StoryElement] into a widget.
///
/// **Lifecycle and ownership.** A renderer is a long-lived, shared object
/// owned by the `StoryRendererRegistry` it is registered with. It builds
/// widgets for many elements and must not keep per-element state. Resources
/// tied to one element (image streams, animation controllers, players) belong
/// in the `State` of the widget [build] returns, so Flutter creates and
/// disposes them with the element's subtree. [dispose] releases resources
/// shared across elements and is called by the registry when the renderer is
/// replaced or the registry is disposed.
///
/// **Async resources.** [build] must return synchronously. Content that loads
/// asynchronously shows a [StoryElementLoading] until ready and a
/// [StoryElementError] on failure.
///
/// Subclass with the element type it renders:
///
/// ```dart
/// class PollRenderer extends StoryElementRenderer<CustomElement> {
///   const PollRenderer();
///
///   @override
///   String get id => 'custom:poll';
///
///   @override
///   bool supports(StoryElement element) =>
///       element is CustomElement && element.customType == 'poll';
///
///   @override
///   Widget buildElement(
///     BuildContext context,
///     CustomElement element,
///     StoryRenderContext renderContext,
///   ) => PollWidget(data: element.data);
/// }
/// ```
abstract class StoryElementRenderer<E extends StoryElement> {
  /// Const constructor for subclasses.
  const StoryElementRenderer();

  /// Unique identifier within a registry, such as `image` or `custom:poll`.
  String get id;

  /// Whether this renderer can build [element]. Defaults to a type check.
  bool supports(StoryElement element) => element is E;

  /// Builds [element] to fill a box of the element's unscaled size.
  ///
  /// Positioning, rotation, scale, flipping, opacity, and semantics labels are
  /// applied by the caller; the renderer only draws the content.
  Widget buildElement(
    BuildContext context,
    E element,
    StoryRenderContext renderContext,
  );

  /// Builds `renderContext.element`. Called by the framework.
  Widget build(BuildContext context, StoryRenderContext renderContext) =>
      buildElement(context, renderContext.element as E, renderContext);

  /// Releases resources shared across elements. Defaults to doing nothing.
  void dispose() {}
}
