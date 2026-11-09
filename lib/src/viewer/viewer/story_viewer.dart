import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../animations/story_curves.dart';
import '../../animations/story_transition.dart';
import '../../animations/story_transition_registry.dart';
import '../../animations/story_transition_switcher.dart';
import '../../composition/document/story_document.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/items/item_timing.dart';
import '../../composition/items/story_item.dart';
import '../../configuration/playback/story_playback_config.dart';
import '../../configuration/viewer/story_viewer_config.dart';
import '../../core/enums/story_enums.dart';
import '../../core/errors/story_exceptions.dart';
import '../../engine/controller/story_controller.dart';
import '../../engine/lifecycle/story_app_lifecycle_binding.dart';
import '../../engine/playback/playback_events.dart';
import '../../engine/state/story_selection.dart';
import '../../engine/widgets/story_playback_selector.dart';
import '../../gestures/handlers/default_gesture_handlers.dart';
import '../../gestures/story_gesture_registry.dart';
import '../../interactions/story_interaction_controller.dart';
import '../../media/contracts/story_media_controller.dart';
import '../../overlays/story_overlay.dart';
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
    this.gestureRegistry,
    this.transitionRegistry,
    this.overlays = const [],
    this.interactionController,
    this.onInteraction,
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
    this.gestureRegistry,
    this.transitionRegistry,
    this.overlays = const [],
    this.interactionController,
    this.onInteraction,
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

  /// Gesture handlers, or `null` for the defaults built from [config]
  /// (owned by the viewer). A supplied registry is used as is; the gesture
  /// settings in [config] apply only to the defaults.
  final StoryGestureRegistry? gestureRegistry;

  /// Transitions, or `null` for the built-in presets (owned by the viewer).
  final StoryTransitionRegistry? transitionRegistry;

  /// App overlays composed above the content, alongside the built-in top bar
  /// and footer.
  final List<StoryOverlay> overlays;

  /// Interaction state for polls, quizzes, and other interactive elements,
  /// or `null` for one owned by the viewer. Supply your own to seed results
  /// or keep answers across viewer sessions.
  final StoryInteractionController? interactionController;

  /// Receives interactions when the viewer owns the interaction controller.
  final StoryInteractionCallback? onInteraction;

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
  StoryGestureRegistry? _ownedGestures;
  StoryTransitionRegistry? _ownedTransitions;
  StoryInteractionController? _ownedInteractions;
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
    final ownedGestures = _ownedGestures;
    if (ownedGestures != null &&
        (widget.gestureRegistry != null ||
            _gestureSettingsChanged(oldWidget.config, widget.config))) {
      ownedGestures.dispose();
      _ownedGestures = null;
    }
    final ownedTransitions = _ownedTransitions;
    if (widget.transitionRegistry != null && ownedTransitions != null) {
      ownedTransitions.dispose();
      _ownedTransitions = null;
    }
  }

  static bool _gestureSettingsChanged(
          StoryViewerConfig a, StoryViewerConfig b) =>
      a.previousTapFraction != b.previousTapFraction ||
      a.dismissDistance != b.dismissDistance ||
      a.longPressToPause != b.longPressToPause ||
      a.swipeBetweenGroups != b.swipeBetweenGroups ||
      a.swipeDownToDismiss != b.swipeDownToDismiss;

  StoryGestureRegistry _defaultGestures() {
    final config = widget.config;
    final registry = StoryGestureRegistry.withDefaults(
      previousTapFraction: config.previousTapFraction,
      dismissDistance: config.dismissDistance,
    );
    if (!config.longPressToPause) {
      registry.setEnabled(StoryHoldToPauseHandler.handlerId, enabled: false);
    }
    if (!config.swipeBetweenGroups) {
      registry.setEnabled(StorySwipeGroupsHandler.handlerId, enabled: false);
    }
    if (!config.swipeDownToDismiss) {
      registry.setEnabled(StorySwipeDismissHandler.handlerId, enabled: false);
    }
    return registry;
  }

  @override
  void dispose() {
    _detach(disposeOwned: true);
    _ownedRegistry?.dispose();
    _ownedGestures?.dispose();
    _ownedTransitions?.dispose();
    _ownedInteractions?.dispose();
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
    final gestures =
        widget.gestureRegistry ?? (_ownedGestures ??= _defaultGestures());
    final transitions = widget.transitionRegistry ??
        (_ownedTransitions ??= StoryTransitionRegistry.withDefaults());
    final interactions = widget.interactionController ??
        (_ownedInteractions ??= StoryInteractionController(
          // Reads the current widget, so a new callback takes effect.
          onInteraction: (event) => widget.onInteraction?.call(event),
        ));

    final parts = StoryViewerParts(
      controller: controller,
      content: _StoryViewerContent(
        controller: controller,
        registry: registry,
        transitions: transitions,
        options: widget.renderOptions,
        config: widget.config,
        interactive: false,
      ),
      interactiveContent: _StoryViewerContent(
        controller: controller,
        registry: registry,
        transitions: transitions,
        options: widget.renderOptions,
        config: widget.config,
        interactive: true,
      ),
      gestures: StoryViewerGestureLayer(
        controller: controller,
        registry: gestures,
        onDismiss: widget.onDismiss,
        keyboardShortcuts: widget.config.keyboardShortcuts,
        previousButtonFraction: widget.config.previousTapFraction,
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
      overlays: widget.overlays,
    );

    return StoryInteractionScope(
      controller: interactions,
      holdPlayback: () => controller.acquirePause(StoryPauseReason.interaction),
      child: widget.layoutBuilder?.call(context, parts) ??
          StoryViewerDefaultLayout(parts: parts, config: widget.config),
    );
  }
}

/// The current item, rebuilt only when the location changes, animated with
/// the configured transition.
class _StoryViewerContent extends StatefulWidget {
  const _StoryViewerContent({
    required this.controller,
    required this.registry,
    required this.transitions,
    required this.options,
    required this.config,
    required this.interactive,
  });

  final StoryController controller;
  final StoryRendererRegistry registry;
  final StoryTransitionRegistry transitions;
  final StoryRenderOptions options;
  final StoryViewerConfig config;

  /// Whether this layer draws the interactive elements (above the gesture
  /// layer) or everything else (below it).
  final bool interactive;

  @override
  State<_StoryViewerContent> createState() => _StoryViewerContentState();
}

class _StoryViewerContentState extends State<_StoryViewerContent> {
  StorySelection<(int, int)>? _selection;
  (int, int)? _location;
  (int, int)? _previous;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(_StoryViewerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _previous = null;
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
    final selection = widget.controller
        .select((state) => (state.groupIndex, state.itemIndex))
      ..addListener(_onLocationChanged);
    _selection = selection;
    _location = selection.value;
  }

  void _detach() {
    final selection = _selection;
    if (selection == null) return;
    selection
      ..removeListener(_onLocationChanged)
      ..dispose();
    _selection = null;
  }

  void _onLocationChanged() {
    final selection = _selection;
    if (selection == null) return;
    setState(() {
      _previous = _location;
      _location = selection.value;
    });
  }

  static bool _isInteractive(StoryElement element) => element.isInteractive;

  static bool _isStatic(StoryElement element) => !element.isInteractive;

  /// The transition into [item] at [location], or `null` to cut.
  StoryTransitionConfiguration? _transitionInto(
      (int, int) location, StoryItem item) {
    final previous = _previous;
    if (previous == null || previous == location) return null;
    final config = widget.config;
    final chosen = previous.$1 != location.$1
        ? config.groupTransition
        : item.transition ?? config.itemTransition;
    if (chosen == null) return null;
    return config.reducesMotion(context)
        ? config.reducedMotionTransition
        : chosen;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final item = controller.currentItem;
    final location = _location;
    if (item == null || location == null) return const SizedBox.shrink();

    final transition = _transitionInto(location, item);
    final previous = _previous;
    final backward = previous != null &&
        (previous.$1 > location.$1 ||
            (previous.$1 == location.$1 && previous.$2 > location.$2));

    return StoryTransitionSwitcher(
      childKey: ('story-item', location.$1, item.id),
      transition: transition == null
          ? null
          : widget.transitions.resolve(transition.type),
      duration: transition?.duration ?? Duration.zero,
      curve: storyCurveNamed(transition?.curve ?? 'easeInOut'),
      direction: backward
          ? StoryTransitionDirection.backward
          : StoryTransitionDirection.forward,
      parameters: transition?.parameters ?? const {},
      child: StoryItemView(
        document: controller.document,
        item: item,
        registry: widget.registry,
        options: widget.options,
        paintBackground: !widget.interactive,
        elementFilter: widget.interactive ? _isInteractive : _isStatic,
      ),
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
