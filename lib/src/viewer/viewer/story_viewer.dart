import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../composition/document/story_document.dart';
import '../../configuration/playback/story_playback_config.dart';
import '../../configuration/viewer/story_viewer_config.dart';
import '../../core/enums/story_enums.dart';
import '../../core/errors/story_exceptions.dart';
import '../../engine/controller/story_controller.dart';
import '../../engine/lifecycle/story_app_lifecycle_binding.dart';
import '../../engine/playback/playback_events.dart';
import '../../engine/widgets/story_playback_selector.dart';
import '../../media/contracts/story_media_controller.dart';
import '../../rendering/options/story_render_options.dart';
import '../../rendering/registry/story_renderer_registry.dart';
import '../../rendering/widgets/story_item_view.dart';
import '../controls/story_viewer_controls.dart';
import '../gestures/story_viewer_gesture_layer.dart';
import '../layouts/story_viewer_layout.dart';
import '../progress/story_progress_bar.dart';

/// Builds a viewer overlay (header, footer, progress, loading) for the
/// current playback.
typedef StoryViewerBuilder = Widget Function(
    BuildContext context, StoryController controller);

/// Builds the overlay shown when playback fails.
typedef StoryViewerErrorBuilder = Widget Function(
    BuildContext context, StoryController controller, StoryException? error);

/// Arranges the viewer's parts; replaces the whole default layout.
typedef StoryViewerLayoutBuilder = Widget Function(
    BuildContext context, StoryViewerParts parts);

/// Presents a [StoryDocument] with playback, progress, navigation gestures,
/// and replaceable UI.
///
/// The viewer is a presentation layer over [StoryController]; all timing and
/// navigation logic lives in the controller.
///
/// ```dart
/// StoryViewer(
///   document: document,
///   onDismiss: () => Navigator.pop(context),
///   onComplete: () => Navigator.pop(context),
/// )
/// ```
///
/// Use [StoryViewer.controller] to drive playback yourself (for example to
/// show your own pause button); the caller then owns and disposes the
/// controller. Otherwise the viewer creates, owns, and disposes one.
///
/// Every part can be replaced: [headerBuilder], [footerBuilder],
/// [progressBuilder], [loadingBuilder], [errorBuilder], or the entire
/// arrangement with [layoutBuilder]. Element rendering is customized with
/// [registry] and [renderOptions].
///
/// Progress ticks repaint only the progress bar; the story content rebuilds
/// only when the current item changes.
class StoryViewer extends StatefulWidget {
  /// Creates a viewer that owns a controller for [document].
  const StoryViewer({
    required StoryDocument this.document,
    this.initialLocation,
    this.playbackConfig = const StoryPlaybackConfig(),
    this.mediaFactories = const [],
    this.durationProviders = const {},
    this.config = const StoryViewerConfig(),
    this.registry,
    this.renderOptions = const StoryRenderOptions(),
    this.headerBuilder,
    this.footerBuilder,
    this.progressBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.layoutBuilder,
    this.onDismiss,
    this.onComplete,
    super.key,
  }) : controller = null;

  /// Creates a viewer driven by an external [controller].
  ///
  /// The caller owns [controller] and must dispose it after the viewer.
  const StoryViewer.controller({
    required StoryController this.controller,
    this.config = const StoryViewerConfig(),
    this.registry,
    this.renderOptions = const StoryRenderOptions(),
    this.headerBuilder,
    this.footerBuilder,
    this.progressBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.layoutBuilder,
    this.onDismiss,
    this.onComplete,
    super.key,
  })  : document = null,
        initialLocation = null,
        playbackConfig = const StoryPlaybackConfig(),
        mediaFactories = const [],
        durationProviders = const {};

  /// The document to play when the viewer owns its controller.
  final StoryDocument? document;

  /// An external controller, or `null` when the viewer owns one.
  final StoryController? controller;

  /// Where the owned controller starts, such as the group the user tapped.
  /// Defaults to the first item.
  final StoryItemLocation? initialLocation;

  /// Timing for the owned controller.
  final StoryPlaybackConfig playbackConfig;

  /// Media providers for the owned controller.
  final List<StoryMediaControllerFactory> mediaFactories;

  /// Custom duration providers for the owned controller.
  final Map<String, StoryDurationProvider> durationProviders;

  /// Presentation and interaction settings.
  final StoryViewerConfig config;

  /// Element renderers, or `null` for the built-in ones (owned by the viewer).
  final StoryRendererRegistry? registry;

  /// Rendering options for story content.
  final StoryRenderOptions renderOptions;

  /// Replaces the default [StoryViewerHeader].
  final StoryViewerBuilder? headerBuilder;

  /// Adds a footer (none by default).
  final StoryViewerBuilder? footerBuilder;

  /// Replaces the default [StoryProgressBar].
  final StoryViewerBuilder? progressBuilder;

  /// Replaces the default [StoryLoadingIndicator], shown while an item loads
  /// or buffers.
  final StoryViewerBuilder? loadingBuilder;

  /// Replaces the default [StoryViewerErrorView].
  final StoryViewerErrorBuilder? errorBuilder;

  /// Replaces the default [StoryViewerDefaultLayout].
  final StoryViewerLayoutBuilder? layoutBuilder;

  /// Called when the user closes or swipes the viewer away. The default
  /// header shows a close button only when this is set.
  final VoidCallback? onDismiss;

  /// Called when playback reaches the end.
  final VoidCallback? onComplete;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  StoryController? _ownedController;
  StoryController? _active;
  StoryRendererRegistry? _ownedRegistry;
  StoryAppLifecycleBinding? _lifecycle;
  // Cancelled in _detach whenever the controller changes or on dispose.
  // ignore: cancel_subscriptions
  StreamSubscription<StoryPlaybackEvent>? _events;

  @override
  void initState() {
    super.initState();
    widget.config.validate();
    _attach();
  }

  @override
  void didUpdateWidget(StoryViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) widget.config.validate();
    final controllerChanged = oldWidget.controller != widget.controller ||
        oldWidget.document != widget.document ||
        oldWidget.initialLocation != widget.initialLocation ||
        oldWidget.playbackConfig != widget.playbackConfig;
    if (controllerChanged ||
        oldWidget.config.pauseInBackground != widget.config.pauseInBackground) {
      _detach(disposeOwned: controllerChanged);
      _attach();
    }
    final owned = _ownedRegistry;
    if (widget.registry != null && owned != null) {
      owned.dispose();
      _ownedRegistry = null;
    }
  }

  @override
  void dispose() {
    _detach(disposeOwned: true);
    _ownedRegistry?.dispose();
    super.dispose();
  }

  void _attach() {
    final controller = widget.controller ?? _ownedController ?? _createOwned();
    if (controller == null || controller.isDisposed) return;
    _active = controller;
    if (widget.config.pauseInBackground) {
      _lifecycle = StoryAppLifecycleBinding(controller);
    }
    _events = controller.events.listen(_onEvent);
    if (widget.config.autoplay &&
        controller.state.value.status == StoryPlaybackStatus.idle) {
      controller.play();
    }
  }

  StoryController? _createOwned() {
    final document = widget.document;
    if (document == null) return null;
    final controller = StoryController(
      document: document,
      config: widget.playbackConfig,
      mediaFactories: widget.mediaFactories,
      durationProviders: widget.durationProviders,
      initialLocation: widget.initialLocation,
    );
    _ownedController = controller;
    return controller;
  }

  void _detach({required bool disposeOwned}) {
    _lifecycle?.dispose();
    _lifecycle = null;
    final events = _events;
    if (events != null) unawaited(events.cancel());
    _events = null;
    _active = null;
    final owned = _ownedController;
    if (disposeOwned && owned != null) {
      unawaited(owned.dispose());
      _ownedController = null;
    }
  }

  void _onEvent(StoryPlaybackEvent event) {
    if (event is StoryPlaybackCompletedEvent) widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _active;
    if (controller == null || controller.isDisposed) {
      return ColoredBox(color: widget.config.backgroundColor);
    }
    final registry = widget.registry ??
        (_ownedRegistry ??= StoryRendererRegistry.withDefaults());

    final parts = StoryViewerParts(
      controller: controller,
      content: _StoryViewerContent(
        controller: controller,
        registry: registry,
        options: widget.renderOptions,
      ),
      gestures: StoryViewerGestureLayer(
        controller: controller,
        config: widget.config,
        onDismiss: widget.onDismiss,
      ),
      statusOverlay: _StoryViewerStatusOverlay(
        controller: controller,
        loadingBuilder: widget.loadingBuilder,
        errorBuilder: widget.errorBuilder,
      ),
      progress: widget.progressBuilder?.call(context, controller) ??
          StoryProgressBar(controller: controller),
      header: widget.headerBuilder?.call(context, controller) ??
          StoryViewerHeader(controller: controller, onClose: widget.onDismiss),
      footer: widget.footerBuilder?.call(context, controller) ??
          const SizedBox.shrink(),
    );

    return widget.layoutBuilder?.call(context, parts) ??
        StoryViewerDefaultLayout(parts: parts, config: widget.config);
  }
}

/// The current item, rebuilt only when the location changes.
class _StoryViewerContent extends StatelessWidget {
  const _StoryViewerContent({
    required this.controller,
    required this.registry,
    required this.options,
  });

  final StoryController controller;
  final StoryRendererRegistry registry;
  final StoryRenderOptions options;

  @override
  Widget build(BuildContext context) {
    return StoryPlaybackSelector<(int, int)>(
      controller: controller,
      selector: (state) => (state.groupIndex, state.itemIndex),
      builder: (context, location, _) {
        final item = controller.currentItem;
        if (item == null) return const SizedBox.shrink();
        return StoryItemView(
          key: ValueKey(('story-item', location.$1, item.id)),
          document: controller.document,
          item: item,
          registry: registry,
          options: options,
        );
      },
    );
  }
}

/// Loading, buffering, and error overlays.
class _StoryViewerStatusOverlay extends StatelessWidget {
  const _StoryViewerStatusOverlay({
    required this.controller,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final StoryController controller;
  final StoryViewerBuilder? loadingBuilder;
  final StoryViewerErrorBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return StoryPlaybackSelector<
        (StoryPlaybackStatus, StoryBufferingStatus, StoryException?)>(
      controller: controller,
      selector: (state) => (state.status, state.bufferingStatus, state.error),
      builder: (context, status, _) {
        final (playback, buffering, error) = status;
        if (playback == StoryPlaybackStatus.error) {
          return errorBuilder?.call(context, controller, error) ??
              StoryViewerErrorView(error: error, onRetry: controller.play);
        }
        if (playback == StoryPlaybackStatus.loading ||
            buffering == StoryBufferingStatus.buffering) {
          return IgnorePointer(
            child: Center(
              child: loadingBuilder?.call(context, controller) ??
                  const StoryLoadingIndicator(),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
