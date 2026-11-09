import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/models/geometry.dart';

/// The editor's view of the canvas: zoom and pan.
///
/// Viewport state is separate from the document: zooming and panning never
/// create undo steps or change the story.
@immutable
final class StoryEditorViewport {
  /// Creates a viewport.
  const StoryEditorViewport({this.zoom = 1, this.pan = Offset.zero});

  /// The fitted view.
  static const StoryEditorViewport fit = StoryEditorViewport();

  /// Smallest zoom.
  static const double minZoom = 0.25;

  /// Largest zoom.
  static const double maxZoom = 8;

  /// Zoom relative to the fitted canvas (1 = whole canvas visible).
  final double zoom;

  /// Offset of the canvas from the centered position, in screen pixels.
  final Offset pan;

  /// Returns a copy with the given fields replaced; [zoom] is clamped.
  StoryEditorViewport copyWith({double? zoom, Offset? pan}) =>
      StoryEditorViewport(
        zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
        pan: pan ?? this.pan,
      );

  @override
  bool operator ==(Object other) =>
      other is StoryEditorViewport && other.zoom == zoom && other.pan == pan;

  @override
  int get hashCode => Object.hash(zoom, pan);
}

/// Converts between screen positions in the editor and canvas coordinates.
@immutable
final class StoryViewportMapping {
  /// Creates a mapping for a [viewportSize] widget showing a canvas of
  /// [canvasSize] with [viewport].
  const StoryViewportMapping({
    required this.viewportSize,
    required this.canvasSize,
    this.viewport = StoryEditorViewport.fit,
    this.margin = 24,
  });

  /// Size of the editing area on screen.
  final Size viewportSize;

  /// Canvas size in canvas units.
  final StorySize canvasSize;

  /// Zoom and pan.
  final StoryEditorViewport viewport;

  /// Space kept around the fitted canvas, in screen pixels.
  final double margin;

  /// Screen pixels per canvas unit when fitted.
  double get fitScale {
    if (canvasSize.isEmpty) return 1;
    final width = math.max(1.0, viewportSize.width - margin * 2);
    final height = math.max(1.0, viewportSize.height - margin * 2);
    return math.min(width / canvasSize.width, height / canvasSize.height);
  }

  /// Screen pixels per canvas unit.
  double get scale => fitScale * viewport.zoom;

  /// Screen position of the canvas top-left corner.
  Offset get origin => Offset(
        (viewportSize.width - canvasSize.width * scale) / 2 + viewport.pan.dx,
        (viewportSize.height - canvasSize.height * scale) / 2 + viewport.pan.dy,
      );

  /// The canvas rectangle on screen.
  Rect get canvasRect =>
      origin & Size(canvasSize.width * scale, canvasSize.height * scale);

  /// Screen position of a canvas point.
  Offset toScreen(StoryPoint point) =>
      origin + Offset(point.x * scale, point.y * scale);

  /// Canvas point at a screen position.
  StoryPoint toCanvas(Offset screen) {
    final local = screen - origin;
    return StoryPoint(local.dx / scale, local.dy / scale);
  }

  /// Converts a screen distance to canvas units.
  double toCanvasDistance(double screenDistance) => screenDistance / scale;

  /// The viewport after zooming by [factor] around [focal] (screen), keeping
  /// the canvas point under [focal] in place.
  StoryEditorViewport zoomAround(Offset focal, double factor) {
    final before = toCanvas(focal);
    final zoomed = viewport.copyWith(zoom: viewport.zoom * factor);
    final next = StoryViewportMapping(
      viewportSize: viewportSize,
      canvasSize: canvasSize,
      viewport: zoomed,
      margin: margin,
    );
    final drift = focal - next.toScreen(before);
    return zoomed.copyWith(pan: zoomed.pan + drift);
  }
}
