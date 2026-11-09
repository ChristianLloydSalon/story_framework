import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The editor's built-in vector icons.
///
/// They are drawn in code on a 24×24 grid, so the editor needs no icon font
/// or asset. Custom tools can use them through `StoryEditorTool.icon`.
enum StoryEditorIcons {
  /// Selection arrow.
  select,

  /// Text.
  text,

  /// Smiley sticker.
  sticker,

  /// Picture.
  image,

  /// Video camera.
  video,

  /// Square and circle.
  shape,

  /// Pen.
  draw,

  /// Eraser.
  eraser,

  /// Undo arrow.
  undo,

  /// Redo arrow.
  redo,

  /// Two overlapping squares.
  duplicate,

  /// Trash can.
  delete,

  /// Open eye.
  visible,

  /// Crossed-out eye.
  hidden,

  /// Closed padlock.
  lock,

  /// Open padlock.
  unlock,

  /// Upward chevron.
  chevronUp,

  /// Downward chevron.
  chevronDown,

  /// Left chevron.
  chevronLeft,

  /// Right chevron.
  chevronRight,

  /// Plus.
  plus,

  /// Minus.
  minus,

  /// Align left edges.
  alignLeft,

  /// Align horizontal centers.
  alignCenter,

  /// Align right edges.
  alignRight,

  /// Align top edges.
  alignTop,

  /// Align vertical middles.
  alignMiddle,

  /// Align bottom edges.
  alignBottom,

  /// Distribute horizontally.
  distributeHorizontal,

  /// Distribute vertically.
  distributeVertical,

  /// Rotate counterclockwise.
  rotateLeft,

  /// Rotate clockwise.
  rotateRight,

  /// Flip horizontally.
  flipHorizontal,

  /// Flip vertically.
  flipVertical,

  /// Half-filled circle.
  opacity,

  /// Arrow up to a bar.
  bringToFront,

  /// Arrow up.
  bringForward,

  /// Arrow down.
  sendBackward,

  /// Arrow down to a bar.
  sendToBack,

  /// Bold "B".
  bold,

  /// Italic "I".
  italic,

  /// Left-aligned lines.
  textLeft,

  /// Centered lines.
  textCenter,

  /// Right-aligned lines.
  textRight,

  /// Justified lines.
  textJustify,

  /// Stacked layers.
  layers,

  /// Four-pointed sparkle.
  sparkle,

  /// Clock.
  clock,

  /// Person.
  person,

  /// Diagonal resize arrows.
  scale,

  /// Poll card.
  interactive,

  /// Music note.
  audio,

  /// Four tiles.
  widget,
}

/// Draws a [StoryEditorIcons] icon.
class StoryEditorIcon extends StatelessWidget {
  /// Creates an icon.
  const StoryEditorIcon(
    this.icon, {
    this.size = 20,
    this.color,
    super.key,
  });

  /// Which icon.
  final StoryEditorIcons icon;

  /// Width and height in logical pixels.
  final double size;

  /// Stroke color; defaults to the ambient text color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color =
        this.color ?? DefaultTextStyle.of(context).style.color ?? _white;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(icon, color)),
    );
  }
}

const Color _white = Color(0xFFFFFFFF);

final class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);

  final StoryEditorIcons icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    _draw(canvas, icon, stroke, fill);
    canvas.restore();
  }

  /// Draws [draw] mirrored left-to-right or top-to-bottom.
  static void _mirrored(Canvas canvas, void Function() draw,
      {required bool horizontal}) {
    canvas
      ..save()
      ..translate(horizontal ? 24 : 0, horizontal ? 0 : 24)
      ..scale(horizontal ? -1 : 1, horizontal ? 1 : -1);
    draw();
    canvas.restore();
  }

  /// Draws [draw] rotated a quarter turn clockwise.
  static void _rotated(Canvas canvas, void Function() draw) {
    canvas
      ..save()
      ..translate(24, 0)
      ..rotate(math.pi / 2);
    draw();
    canvas.restore();
  }

  static Path _lines(List<List<double>> polylines) {
    final path = Path();
    for (final line in polylines) {
      path.moveTo(line[0], line[1]);
      for (var i = 2; i + 1 < line.length; i += 2) {
        path.lineTo(line[i], line[i + 1]);
      }
    }
    return path;
  }

  static RRect _box(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  /// An arc around [center] with an arrowhead at its end.
  static void _arcArrow(Canvas canvas, Paint stroke, Offset center,
      double radius, double start, double sweep) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, start, sweep, false, stroke);
    final end = start + sweep;
    final tip = center + Offset(math.cos(end), math.sin(end)) * radius;
    final direction = sweep >= 0 ? 1.0 : -1.0;
    final tangent = Offset(-math.sin(end), math.cos(end)) * direction;
    for (final turn in [2.5, -2.5]) {
      final back = Offset(
        tangent.dx * math.cos(turn) - tangent.dy * math.sin(turn),
        tangent.dx * math.sin(turn) + tangent.dy * math.cos(turn),
      );
      canvas.drawLine(tip, tip + back * 4.5, stroke);
    }
  }

  static void _draw(
      Canvas canvas, StoryEditorIcons icon, Paint stroke, Paint fill) {
    void lines(List<List<double>> polylines) =>
        canvas.drawPath(_lines(polylines), stroke);
    void box(double x, double y, double w, double h, [double r = 2]) =>
        canvas.drawRRect(_box(x, y, w, h, r), stroke);
    void circle(double x, double y, double r) =>
        canvas.drawCircle(Offset(x, y), r, stroke);
    void dot(double x, double y, [double r = 1.2]) =>
        canvas.drawCircle(Offset(x, y), r, fill);

    switch (icon) {
      case StoryEditorIcons.select:
        lines([
          [5.5, 3.5, 18.5, 11.5, 12, 13, 9, 19.5, 5.5, 3.5],
        ]);
      case StoryEditorIcons.text:
        lines([
          [5, 5, 19, 5],
          [12, 5, 12, 19],
          [9, 19, 15, 19],
        ]);
      case StoryEditorIcons.sticker:
        circle(12, 12, 9);
        canvas.drawArc(Rect.fromLTWH(7.5, 8.5, 9, 8), 0.2 * math.pi,
            0.6 * math.pi, false, stroke);
        dot(9, 9.8);
        dot(15, 9.8);
      case StoryEditorIcons.image:
        box(3, 4.5, 18, 15, 3);
        circle(9, 9.5, 1.7);
        lines([
          [3.5, 17, 9, 12.5, 13, 15.5, 16, 13, 20.5, 16.5],
        ]);
      case StoryEditorIcons.video:
        box(3, 6, 13, 12, 2.5);
        lines([
          [16, 10.5, 21, 7.5, 21, 16.5, 16, 13.5],
        ]);
      case StoryEditorIcons.shape:
        box(3.5, 3.5, 10, 10);
        circle(15.5, 15.5, 5);
      case StoryEditorIcons.draw:
        lines([
          [4.5, 19.5, 5.5, 15, 15.5, 5, 19, 8.5, 9, 18.5, 4.5, 19.5],
          [13.5, 7, 17, 10.5],
        ]);
      case StoryEditorIcons.eraser:
        lines([
          [10, 19.5, 5, 14.5, 14, 5.5, 19.5, 11, 11, 19.5],
          [8.5, 11, 14, 16.5],
          [10, 19.5, 20, 19.5],
        ]);
      case StoryEditorIcons.undo:
        final path = Path()
          ..moveTo(4.5, 9.5)
          ..lineTo(14.5, 9.5)
          ..arcToPoint(const Offset(14.5, 19.5),
              radius: const Radius.circular(5))
          ..lineTo(10.5, 19.5);
        canvas.drawPath(path, stroke);
        lines([
          [8.5, 5.5, 4.5, 9.5, 8.5, 13.5],
        ]);
      case StoryEditorIcons.redo:
        _mirrored(
            canvas,
            horizontal: true,
            () => _draw(canvas, StoryEditorIcons.undo, stroke, fill));
      case StoryEditorIcons.duplicate:
        box(8.5, 8.5, 12, 12, 2.5);
        final back = Path()
          ..moveTo(15.5, 8.5)
          ..lineTo(15.5, 6)
          ..arcToPoint(const Offset(13, 3.5),
              radius: const Radius.circular(2.5))
          ..lineTo(6, 3.5)
          ..arcToPoint(const Offset(3.5, 6), radius: const Radius.circular(2.5))
          ..lineTo(3.5, 13)
          ..arcToPoint(const Offset(6, 15.5),
              radius: const Radius.circular(2.5))
          ..lineTo(8.5, 15.5);
        canvas.drawPath(back, stroke);
      case StoryEditorIcons.delete:
        lines([
          [4, 6.5, 20, 6.5],
          [9, 6.5, 9, 4, 15, 4, 15, 6.5],
          [6, 6.5, 7, 20, 17, 20, 18, 6.5],
          [10, 10.5, 10, 16],
          [14, 10.5, 14, 16],
        ]);
      case StoryEditorIcons.visible:
        final eye = Path()
          ..moveTo(2.5, 12)
          ..quadraticBezierTo(12, 2.5, 21.5, 12)
          ..quadraticBezierTo(12, 21.5, 2.5, 12)
          ..close();
        canvas.drawPath(eye, stroke);
        circle(12, 12, 3);
      case StoryEditorIcons.hidden:
        _draw(canvas, StoryEditorIcons.visible, stroke, fill);
        lines([
          [4, 4, 20, 20],
        ]);
      case StoryEditorIcons.lock:
        box(5, 11, 14, 10, 2.5);
        final shackle = Path()
          ..moveTo(8, 11)
          ..lineTo(8, 8)
          ..arcToPoint(const Offset(16, 8), radius: const Radius.circular(4))
          ..lineTo(16, 11);
        canvas.drawPath(shackle, stroke);
      case StoryEditorIcons.unlock:
        box(5, 11, 14, 10, 2.5);
        final shackle = Path()
          ..moveTo(8, 11)
          ..lineTo(8, 8)
          ..arcToPoint(const Offset(15.8, 6.5),
              radius: const Radius.circular(4));
        canvas.drawPath(shackle, stroke);
      case StoryEditorIcons.chevronUp:
        lines([
          [6, 15, 12, 9, 18, 15],
        ]);
      case StoryEditorIcons.chevronDown:
        lines([
          [6, 9, 12, 15, 18, 9],
        ]);
      case StoryEditorIcons.chevronLeft:
        lines([
          [15, 6, 9, 12, 15, 18],
        ]);
      case StoryEditorIcons.chevronRight:
        lines([
          [9, 6, 15, 12, 9, 18],
        ]);
      case StoryEditorIcons.plus:
        lines([
          [12, 5, 12, 19],
          [5, 12, 19, 12],
        ]);
      case StoryEditorIcons.minus:
        lines([
          [5, 12, 19, 12],
        ]);
      case StoryEditorIcons.alignLeft:
        lines([
          [4, 3, 4, 21],
        ]);
        box(8, 6, 12, 4, 1.5);
        box(8, 14, 7, 4, 1.5);
      case StoryEditorIcons.alignCenter:
        lines([
          [12, 3, 12, 21],
        ]);
        box(5, 6, 14, 4, 1.5);
        box(7.5, 14, 9, 4, 1.5);
      case StoryEditorIcons.alignRight:
        _mirrored(
            canvas,
            horizontal: true,
            () => _draw(canvas, StoryEditorIcons.alignLeft, stroke, fill));
      case StoryEditorIcons.alignTop:
        lines([
          [3, 4, 21, 4],
        ]);
        box(6, 8, 4, 12, 1.5);
        box(14, 8, 4, 7, 1.5);
      case StoryEditorIcons.alignMiddle:
        lines([
          [3, 12, 21, 12],
        ]);
        box(6, 5, 4, 14, 1.5);
        box(14, 7.5, 4, 9, 1.5);
      case StoryEditorIcons.alignBottom:
        _mirrored(
            canvas,
            horizontal: false,
            () => _draw(canvas, StoryEditorIcons.alignTop, stroke, fill));
      case StoryEditorIcons.distributeHorizontal:
        lines([
          [4, 3, 4, 21],
          [20, 3, 20, 21],
        ]);
        box(9, 7, 6, 10, 1.5);
      case StoryEditorIcons.distributeVertical:
        _rotated(
            canvas,
            () => _draw(
                canvas, StoryEditorIcons.distributeHorizontal, stroke, fill));
      case StoryEditorIcons.rotateRight:
        _arcArrow(canvas, stroke, const Offset(12, 12.5), 7.5,
            -math.pi / 2 - 1.9, 4.6);
      case StoryEditorIcons.rotateLeft:
        _mirrored(
            canvas,
            horizontal: true,
            () => _draw(canvas, StoryEditorIcons.rotateRight, stroke, fill));
      case StoryEditorIcons.flipHorizontal:
        lines([
          [12, 3, 12, 21],
          [9, 7, 3.5, 17, 9, 17, 9, 7],
        ]);
        canvas.drawPath(
            _lines([
              [15, 7, 20.5, 17, 15, 17, 15, 7],
            ]),
            fill);
      case StoryEditorIcons.flipVertical:
        _rotated(canvas,
            () => _draw(canvas, StoryEditorIcons.flipHorizontal, stroke, fill));
      case StoryEditorIcons.opacity:
        circle(12, 12, 8.5);
        canvas.drawArc(
            Rect.fromCircle(center: const Offset(12, 12), radius: 8.5),
            math.pi / 2,
            math.pi,
            true,
            fill);
      case StoryEditorIcons.bringToFront:
        lines([
          [5, 4.5, 19, 4.5],
          [12, 20, 12, 9],
          [7, 14, 12, 9, 17, 14],
        ]);
      case StoryEditorIcons.bringForward:
        lines([
          [12, 19, 12, 5.5],
          [7, 10.5, 12, 5.5, 17, 10.5],
        ]);
      case StoryEditorIcons.sendBackward:
        _mirrored(
            canvas,
            horizontal: false,
            () => _draw(canvas, StoryEditorIcons.bringForward, stroke, fill));
      case StoryEditorIcons.sendToBack:
        _mirrored(
            canvas,
            horizontal: false,
            () => _draw(canvas, StoryEditorIcons.bringToFront, stroke, fill));
      case StoryEditorIcons.bold:
        final bold = Paint.from(stroke)..strokeWidth = 2.4;
        final path = Path()
          ..moveTo(7, 4.5)
          ..lineTo(12.5, 4.5)
          ..arcToPoint(const Offset(12.5, 11.5),
              radius: const Radius.circular(3.5))
          ..lineTo(7, 11.5)
          ..moveTo(7, 11.5)
          ..lineTo(13.5, 11.5)
          ..arcToPoint(const Offset(13.5, 19.5),
              radius: const Radius.circular(4))
          ..lineTo(7, 19.5)
          ..lineTo(7, 4.5);
        canvas.drawPath(path, bold);
      case StoryEditorIcons.italic:
        lines([
          [10, 4.5, 18, 4.5],
          [6, 19.5, 14, 19.5],
          [14, 4.5, 10, 19.5],
        ]);
      case StoryEditorIcons.textLeft:
        lines([
          [4, 6, 20, 6],
          [4, 10, 14, 10],
          [4, 14, 20, 14],
          [4, 18, 12, 18],
        ]);
      case StoryEditorIcons.textCenter:
        lines([
          [4, 6, 20, 6],
          [7, 10, 17, 10],
          [4, 14, 20, 14],
          [8, 18, 16, 18],
        ]);
      case StoryEditorIcons.textRight:
        _mirrored(
            canvas,
            horizontal: true,
            () => _draw(canvas, StoryEditorIcons.textLeft, stroke, fill));
      case StoryEditorIcons.textJustify:
        lines([
          [4, 6, 20, 6],
          [4, 10, 20, 10],
          [4, 14, 20, 14],
          [4, 18, 20, 18],
        ]);
      case StoryEditorIcons.layers:
        lines([
          [12, 3, 21, 8, 12, 13, 3, 8, 12, 3],
          [3, 12, 12, 17, 21, 12],
          [3, 16, 12, 21, 21, 16],
        ]);
      case StoryEditorIcons.sparkle:
        final star = Path()
          ..moveTo(12, 3)
          ..quadraticBezierTo(13, 11, 21, 12)
          ..quadraticBezierTo(13, 13, 12, 21)
          ..quadraticBezierTo(11, 13, 3, 12)
          ..quadraticBezierTo(11, 11, 12, 3)
          ..close();
        canvas.drawPath(star, stroke);
      case StoryEditorIcons.clock:
        circle(12, 12, 8.5);
        lines([
          [12, 7.5, 12, 12, 15, 14],
        ]);
      case StoryEditorIcons.person:
        circle(12, 8, 3.8);
        final body = Path()
          ..moveTo(4.5, 20)
          ..arcToPoint(const Offset(19.5, 20),
              radius: const Radius.circular(7.5));
        canvas.drawPath(body, stroke);
      case StoryEditorIcons.scale:
        lines([
          [4, 14, 4, 20, 10, 20],
          [14, 4, 20, 4, 20, 10],
          [20, 4, 13.5, 10.5],
          [4, 20, 10.5, 13.5],
        ]);
      case StoryEditorIcons.interactive:
        box(3, 5, 18, 14, 3);
        lines([
          [7, 10, 17, 10],
          [7, 14, 12.5, 14],
        ]);
      case StoryEditorIcons.audio:
        lines([
          [9, 17.5, 9, 5, 19, 3, 19, 15.5],
        ]);
        circle(6.5, 17.5, 2.5);
        circle(16.5, 15.5, 2.5);
      case StoryEditorIcons.widget:
        box(3.5, 3.5, 7, 7, 1.5);
        box(13.5, 3.5, 7, 7, 1.5);
        box(3.5, 13.5, 7, 7, 1.5);
        box(13.5, 13.5, 7, 7, 1.5);
    }
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
