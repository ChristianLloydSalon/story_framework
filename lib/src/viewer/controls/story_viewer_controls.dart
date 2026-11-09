import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/errors/story_exceptions.dart';
import '../../engine/controller/story_controller.dart';
import '../../engine/widgets/story_playback_selector.dart';

const TextStyle _overlayText = TextStyle(
  color: Color(0xFFFFFFFF),
  fontSize: 15,
  fontWeight: FontWeight.w600,
  shadows: [Shadow(color: Color(0x80000000), blurRadius: 4)],
);

/// The default header: the current group's title and an optional close
/// button. Rebuilds only when the group changes.
class StoryViewerHeader extends StatelessWidget {
  /// Creates a header for [controller].
  const StoryViewerHeader({required this.controller, this.onClose, super.key});

  /// The controller whose current group is shown.
  final StoryController controller;

  /// Called by the close button; the button is hidden when `null`.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return StoryPlaybackSelector<int>(
      controller: controller,
      selector: (state) => state.groupIndex,
      builder: (context, groupIndex, _) {
        final groups = controller.document.groups;
        final title =
            groupIndex < groups.length ? groups[groupIndex].title : null;
        final close = onClose;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title ?? '',
                  style: _overlayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (close != null) StoryCloseButton(onPressed: close),
            ],
          ),
        );
      },
    );
  }
}

/// A minimal, dependency-free close button drawn as a cross.
class StoryCloseButton extends StatelessWidget {
  /// Creates a close button.
  const StoryCloseButton({
    required this.onPressed,
    this.color = const Color(0xFFFFFFFF),
    this.size = 24,
    super.key,
  });

  /// Called when tapped.
  final VoidCallback onPressed;

  /// Cross color.
  final Color color;

  /// Cross size; the tap target is at least 48×48.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: math.max(48, size),
            height: math.max(48, size),
            child: Center(
              child: CustomPaint(
                size: Size.square(size),
                painter: _CrossPainter(color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(inset, inset),
          Offset(size.width - inset, size.height - inset), paint)
      ..drawLine(Offset(size.width - inset, inset),
          Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.color != color;
}

/// The default loading indicator: a spinning arc.
class StoryLoadingIndicator extends StatefulWidget {
  /// Creates a loading indicator.
  const StoryLoadingIndicator({
    this.color = const Color(0xFFFFFFFF),
    this.size = 36,
    super.key,
  });

  /// Arc color.
  final Color color;

  /// Diameter.
  final double size;

  @override
  State<StoryLoadingIndicator> createState() => _StoryLoadingIndicatorState();
}

class _StoryLoadingIndicatorState extends State<StoryLoadingIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spin = _spin;
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: widget.size,
        child: spin == null
            ? null
            : CustomPaint(painter: _ArcPainter(spin, widget.color)),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.turns, this.color) : super(repaint: turns);

  final Animation<double> turns;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 10;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      turns.value * 2 * math.pi,
      math.pi * 1.4,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.turns != turns || oldDelegate.color != color;
}

/// The default error view: a message and a retry action.
class StoryViewerErrorView extends StatelessWidget {
  /// Creates an error view for [error].
  const StoryViewerErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  /// The playback failure.
  final StoryException? error;

  /// Retries the current item.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Semantics(
          button: true,
          label: "Couldn't load this story. Retry",
          onTap: onRetry,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Couldn't load this story", style: _overlayText),
                    SizedBox(height: 8),
                    Text('Tap to retry',
                        style: TextStyle(color: Color(0xCCFFFFFF))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
