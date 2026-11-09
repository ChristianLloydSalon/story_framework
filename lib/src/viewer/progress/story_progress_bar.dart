import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/enums/story_enums.dart';
import '../../core/models/playback_state.dart';
import '../../engine/controller/story_controller.dart';
import '../../engine/widgets/story_playback_selector.dart';

/// Appearance of a [StoryProgressBar].
@immutable
final class StoryProgressBarStyle {
  /// Creates a progress bar style.
  const StoryProgressBarStyle({
    this.activeColor = const Color(0xFFFFFFFF),
    this.inactiveColor = const Color(0x66FFFFFF),
    this.height = 2.5,
    this.spacing = 4,
    this.radius = 2,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 4),
  });

  /// Filled portion color.
  final Color activeColor;

  /// Unfilled portion color.
  final Color inactiveColor;

  /// Segment thickness.
  final double height;

  /// Gap between segments.
  final double spacing;

  /// Segment corner radius.
  final double radius;

  /// Space around the bar.
  final EdgeInsets padding;

  @override
  bool operator ==(Object other) =>
      other is StoryProgressBarStyle &&
      other.activeColor == activeColor &&
      other.inactiveColor == inactiveColor &&
      other.height == height &&
      other.spacing == spacing &&
      other.radius == radius &&
      other.padding == padding;

  @override
  int get hashCode =>
      Object.hash(activeColor, inactiveColor, height, spacing, radius, padding);
}

/// One segment per item in the current group, filled as items play.
///
/// Progress ticks repaint the bar directly from the controller state without
/// rebuilding any widget; the bar rebuilds only when the group changes.
class StoryProgressBar extends StatelessWidget {
  /// Creates a progress bar for [controller].
  const StoryProgressBar({
    required this.controller,
    this.style = const StoryProgressBarStyle(),
    super.key,
  });

  /// The controller whose progress is shown.
  final StoryController controller;

  /// Appearance.
  final StoryProgressBarStyle style;

  @override
  Widget build(BuildContext context) {
    return StoryPlaybackSelector<(int, int)>(
      controller: controller,
      selector: (state) => (state.groupIndex, state.itemIndex),
      builder: (context, location, _) {
        final (groupIndex, itemIndex) = location;
        final groups = controller.document.groups;
        final count =
            groupIndex < groups.length ? groups[groupIndex].items.length : 0;
        return Semantics(
          label: count == 0 ? null : 'Story ${itemIndex + 1} of $count',
          child: Padding(
            padding: style.padding,
            child: SizedBox(
              height: style.height,
              width: double.infinity,
              child: CustomPaint(
                painter: StoryProgressPainter(
                  state: controller.state,
                  segmentCount: count,
                  style: style,
                  textDirection:
                      Directionality.maybeOf(context) ?? TextDirection.ltr,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints progress segments from a live playback state.
class StoryProgressPainter extends CustomPainter {
  /// Creates a painter that repaints whenever [state] changes.
  StoryProgressPainter({
    required this.state,
    required this.segmentCount,
    required this.style,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: state);

  /// The live playback state.
  final ValueListenable<StoryPlaybackState> state;

  /// Number of segments (items in the current group).
  final int segmentCount;

  /// Appearance.
  final StoryProgressBarStyle style;

  /// Segments run from the leading edge.
  final TextDirection textDirection;

  /// Fill fraction of segment [index] for [snapshot], between 0 and 1.
  static double fillFor(StoryPlaybackState snapshot, int index) {
    if (snapshot.status == StoryPlaybackStatus.completed) return 1;
    if (index < snapshot.itemIndex) return 1;
    if (index > snapshot.itemIndex) return 0;
    return snapshot.progress;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (segmentCount <= 0 || size.width <= 0) return;
    final snapshot = state.value;
    final gaps = style.spacing * (segmentCount - 1);
    final segmentWidth = (size.width - gaps) / segmentCount;
    if (segmentWidth <= 0) return;
    final radius = Radius.circular(style.radius);
    final inactive = Paint()..color = style.inactiveColor;
    final active = Paint()..color = style.activeColor;

    for (var i = 0; i < segmentCount; i++) {
      final start = i * (segmentWidth + style.spacing);
      final left = textDirection == TextDirection.ltr
          ? start
          : size.width - start - segmentWidth;
      final track = Rect.fromLTWH(left, 0, segmentWidth, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(track, radius), inactive);

      final fill = fillFor(snapshot, i);
      if (fill <= 0) continue;
      final fillWidth = segmentWidth * fill;
      final fillLeft = textDirection == TextDirection.ltr
          ? left
          : left + segmentWidth - fillWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(fillLeft, 0, fillWidth, size.height), radius),
        active,
      );
    }
  }

  @override
  bool shouldRepaint(StoryProgressPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.segmentCount != segmentCount ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection;
}
