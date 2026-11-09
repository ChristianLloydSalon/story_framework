import 'package:flutter/widgets.dart';

import '../../configuration/viewer/story_viewer_config.dart';
import '../../engine/controller/story_controller.dart';

/// The pieces of a story viewer, passed to a custom layout.
///
/// Rearrange, wrap, or omit any of them. Keep [gestures] above [content] and
/// below interactive overlays so taps reach your own buttons.
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
  });

  /// The controller driving playback.
  final StoryController controller;

  /// The current story item, scaled to fit.
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
}

/// The default arrangement: content, gestures, and status overlay stacked
/// full-size, with progress and header on top and the footer at the bottom.
///
/// In [StoryViewerLayout.fullscreen], the top and bottom overlays stay inside
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

  /// Supplies the layout mode and background color.
  final StoryViewerConfig config;

  @override
  Widget build(BuildContext context) {
    final fullscreen = config.layout == StoryViewerLayout.fullscreen;
    final top = Column(
      mainAxisSize: MainAxisSize.min,
      children: [parts.progress, parts.header],
    );
    return ColoredBox(
      color: config.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          parts.content,
          parts.gestures,
          parts.statusOverlay,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: fullscreen ? SafeArea(bottom: false, child: top) : top,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: fullscreen
                ? SafeArea(top: false, child: parts.footer)
                : parts.footer,
          ),
        ],
      ),
    );
  }
}
