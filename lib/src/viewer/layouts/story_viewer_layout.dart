import 'package:flutter/widgets.dart';

import '../../configuration/viewer/story_viewer_config.dart';
import '../../engine/controller/story_controller.dart';
import '../../overlays/story_overlay.dart';

/// The pieces of a story viewer, passed to a custom layout.
///
/// Rearrange, wrap, or omit any of them. Keep [gestures] above [content] and
/// below interactive overlays so taps reach your own buttons. Use
/// [StoryOverlayLayer] to place [overlays].
@immutable
final class StoryViewerParts {
  /// Creates the parts.
  const StoryViewerParts({
    required this.controller,
    required this.content,
    required this.gestures,
    required this.statusOverlay,
    required this.progress,
    required this.header,
    required this.footer,
    this.overlays = const [],
  });

  /// The controller driving playback.
  final StoryController controller;

  /// The current story item, scaled to fit, with transitions.
  final Widget content;

  /// Tap, hold, swipe, and keyboard handling; fills its parent.
  final Widget gestures;

  /// Loading, buffering, and error overlays; fills its parent.
  final Widget statusOverlay;

  /// Progress segments for the current group.
  final Widget progress;

  /// The header (by default the group title and close button).
  final Widget header;

  /// The footer (empty by default).
  final Widget footer;

  /// App overlays passed to the viewer.
  final List<StoryOverlay> overlays;
}

/// The default arrangement: content, gestures, and the status overlay fill
/// the viewer; progress and header, footer, and app overlays are composed
/// above them as [StoryOverlay]s.
///
/// The built-in top bar (`story.top`) and footer (`story.footer`) use
/// z-index 100, so app overlays with a lower z-index sit below them and
/// higher ones above. In [StoryViewerLayout.fullscreen], overlays stay inside
/// the safe area.
class StoryViewerDefaultLayout extends StatelessWidget {
  /// Creates the default layout.
  const StoryViewerDefaultLayout({
    required this.parts,
    this.config = const StoryViewerConfig(),
    super.key,
  });

  /// The pieces to arrange.
  final StoryViewerParts parts;

  /// Supplies the layout mode, background color, and motion preference.
  final StoryViewerConfig config;

  @override
  Widget build(BuildContext context) {
    final top = Column(
      mainAxisSize: MainAxisSize.min,
      children: [parts.progress, parts.header],
    );
    final footer = parts.footer;
    return ColoredBox(
      color: config.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          parts.content,
          parts.gestures,
          parts.statusOverlay,
          StoryOverlayLayer(
            controller: parts.controller,
            useSafeArea: config.layout == StoryViewerLayout.fullscreen,
            reduceMotion: config.reducesMotion(context),
            overlays: [
              StoryOverlay(
                id: 'story.top',
                zIndex: 100,
                builder: (context, controller) => top,
              ),
              StoryOverlay(
                id: 'story.footer',
                zIndex: 100,
                alignment: AlignmentDirectional.bottomCenter,
                builder: (context, controller) => footer,
              ),
              ...parts.overlays,
            ],
          ),
        ],
      ),
    );
  }
}
