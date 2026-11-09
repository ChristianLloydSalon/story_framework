import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../../composition/elements/story_element.dart';
import '../../core/enums/story_enums.dart';
import '../../core/errors/story_exceptions.dart';
import '../../media/contracts/story_media_controller.dart';
import '../../media/contracts/story_visual_media.dart';
import '../contracts/story_element_renderer.dart';
import '../conversions.dart';
import 'builtin_renderers.dart';

/// Renders [VideoElement]s.
///
/// In the viewer, the video shows the frames of the controller the playback
/// engine is already driving (found through `StoryMediaScope`), so it is
/// decoded once. Elsewhere it shows the element's `poster`, or a live
/// first-frame preview when `StoryRenderOptions.previewMediaFactories` is set.
final class StoryVideoRenderer extends StoryElementRenderer<VideoElement> {
  /// Creates the video renderer.
  const StoryVideoRenderer();

  @override
  String get id => VideoElement.typeId;

  @override
  Widget buildElement(
    BuildContext context,
    VideoElement element,
    StoryRenderContext renderContext,
  ) =>
      StoryVideoView(element: element, renderContext: renderContext);
}

/// Shows a video element's frames, poster, loading, or error state.
///
/// Rebuilds only when the media status changes, never on position updates,
/// so playing video does not rebuild the widget tree.
class StoryVideoView extends StatefulWidget {
  /// Creates the view.
  const StoryVideoView({
    required this.element,
    required this.renderContext,
    super.key,
  });

  /// The video element.
  final VideoElement element;

  /// Where it is rendered.
  final StoryRenderContext renderContext;

  @override
  State<StoryVideoView> createState() => _StoryVideoViewState();
}

class _StoryVideoViewState extends State<StoryVideoView> {
  StoryMediaController? _media;
  StoryMediaController? _ownedPreview;
  // Cancelled whenever the controller changes and on dispose.
  // ignore: cancel_subscriptions
  StreamSubscription<StoryMediaSnapshot>? _subscription;
  StoryMediaStatus _status = StoryMediaStatus.uninitialized;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(StoryVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.element.id != widget.element.id ||
        oldWidget.element.source != widget.element.source) {
      _disposePreview();
      _resolve();
    }
  }

  @override
  void dispose() {
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    _disposePreview();
    super.dispose();
  }

  void _resolve() {
    final scope = StoryMediaScope.maybeOf(context);
    var media = scope?.lookup(widget.element.id);
    if (media == null && scope == null) {
      media = _ownedPreview ?? _createPreview();
    }
    if (identical(media, _media)) return;
    final previous = _subscription;
    if (previous != null) unawaited(previous.cancel());
    _subscription = null;
    _media = media;
    if (media == null) return;
    _status = media.snapshot.status;
    _error = media.snapshot.error;
    _subscription = media.snapshots.listen(_onSnapshot);
  }

  void _onSnapshot(StoryMediaSnapshot snapshot) {
    if (!mounted) return;
    if (snapshot.status == _status && snapshot.error == _error) return;
    setState(() {
      _status = snapshot.status;
      _error = snapshot.error;
    });
  }

  StoryMediaController? _createPreview() {
    final options = widget.renderContext.options;
    final factory = options.previewMediaFactories
        .firstWhereOrNull((f) => f.supports(widget.element));
    if (factory == null) return null;
    try {
      final controller = factory.create(
        widget.element,
        widget.renderContext.resolveSource(widget.element.source),
      );
      _ownedPreview = controller;
      unawaited(_preparePreview(controller));
      return controller;
    } on StoryException catch (error) {
      _error = error;
      return null;
    }
  }

  Future<void> _preparePreview(StoryMediaController controller) async {
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.seekTo(widget.element.trimStart);
      await controller.pause();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _disposePreview() {
    final preview = _ownedPreview;
    _ownedPreview = null;
    if (preview != null) unawaited(preview.dispose());
  }

  bool get _showsFrames => switch (_status) {
        StoryMediaStatus.ready ||
        StoryMediaStatus.playing ||
        StoryMediaStatus.paused ||
        StoryMediaStatus.buffering ||
        StoryMediaStatus.completed =>
          true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final renderContext = widget.renderContext;
    final error = _error;
    if (error != null) {
      return StoryElementError(renderContext: renderContext, error: error);
    }
    final media = _media;
    if (media is StoryVisualMediaController && _showsFrames) {
      return _VideoFrames(media: media, fit: element.fit.toBoxFit());
    }
    final poster = element.poster;
    if (poster != null) {
      return StoryImageContent(
        renderContext: renderContext,
        source: poster,
        fit: element.fit.toBoxFit(),
      );
    }
    return media == null
        ? const _VideoPlaceholder()
        : StoryElementLoading(renderContext: renderContext);
  }
}

/// Fits the video's natural size into the element box.
class _VideoFrames extends StatelessWidget {
  const _VideoFrames({required this.media, required this.fit});

  final StoryVisualMediaController media;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final size = media.naturalSize;
    final view = media.buildView(context);
    if (size == null || size.isEmpty) return SizedBox.expand(child: view);
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(width: size.width, height: size.height, child: view),
      ),
    );
  }
}

/// Shown for videos that cannot play here and have no poster.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1E1E24),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('▶',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 120)),
          ),
        ),
      ),
    );
  }
}
