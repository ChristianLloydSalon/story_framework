import 'package:meta/meta.dart';

import '../../core/errors/story_exceptions.dart';
import '../../core/models/geometry.dart';

/// How the editor validates the document after each edit.
enum StoryEditValidation {
  /// No validation.
  none,

  /// Validate and expose the result, but accept the edit.
  report,

  /// Reject edits that introduce validation errors.
  reject,
}

/// Editing behavior for `StoryEditorController` and `StoryEditor`.
///
/// Independent of the viewer's configuration.
@immutable
final class StoryEditorConfig {
  /// Creates an editor configuration.
  const StoryEditorConfig({
    this.historyLimit = 100,
    this.snapping = true,
    this.snapThreshold = 8,
    this.rotationSnapDegrees = 45,
    this.nudgeDistance = 1,
    this.largeNudgeDistance = 10,
    this.duplicateOffset = const StoryPoint(40, 40),
    this.minElementSize = 24,
    this.validation = StoryEditValidation.report,
    this.newItemDuration = const Duration(seconds: 5),
    this.keyboardShortcuts = true,
  });

  /// Maximum undo steps kept.
  final int historyLimit;

  /// Whether moving snaps to the canvas and other elements.
  final bool snapping;

  /// Snap distance in screen pixels (independent of zoom).
  final double snapThreshold;

  /// Rotation snaps to multiples of this angle; 0 disables it.
  final double rotationSnapDegrees;

  /// Arrow-key nudge, in canvas units.
  final double nudgeDistance;

  /// Shift+arrow nudge, in canvas units.
  final double largeNudgeDistance;

  /// Offset of duplicated elements from the originals.
  final StoryPoint duplicateOffset;

  /// Smallest width or height a resize can produce, in canvas units.
  final double minElementSize;

  /// Validation after each edit.
  final StoryEditValidation validation;

  /// Display time of newly added story items.
  final Duration newItemDuration;

  /// Whether keyboard shortcuts (undo, delete, nudge, ...) are active.
  final bool keyboardShortcuts;

  /// Throws a [ConfigurationException] if any value is invalid.
  void validate() {
    if (historyLimit <= 0) {
      throw const ConfigurationException('historyLimit must be positive');
    }
    if (snapThreshold < 0 || minElementSize <= 0) {
      throw const ConfigurationException(
          'snapThreshold must be non-negative and minElementSize positive');
    }
    if (newItemDuration <= Duration.zero) {
      throw const ConfigurationException('newItemDuration must be positive');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is StoryEditorConfig &&
      other.historyLimit == historyLimit &&
      other.snapping == snapping &&
      other.snapThreshold == snapThreshold &&
      other.rotationSnapDegrees == rotationSnapDegrees &&
      other.nudgeDistance == nudgeDistance &&
      other.largeNudgeDistance == largeNudgeDistance &&
      other.duplicateOffset == duplicateOffset &&
      other.minElementSize == minElementSize &&
      other.validation == validation &&
      other.newItemDuration == newItemDuration &&
      other.keyboardShortcuts == keyboardShortcuts;

  @override
  int get hashCode => Object.hash(
        historyLimit,
        snapping,
        snapThreshold,
        rotationSnapDegrees,
        nudgeDistance,
        largeNudgeDistance,
        duplicateOffset,
        minElementSize,
        validation,
        newItemDuration,
        keyboardShortcuts,
      );
}
