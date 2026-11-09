import 'package:flutter/widgets.dart';

import '../../core/errors/story_exceptions.dart';

/// How the viewer fits into the screen.
enum StoryViewerLayout {
  /// Fills the screen; overlays avoid system UI with safe areas.
  fullscreen,

  /// Embedded in other content; overlays use the viewer's own bounds.
  inline,
}

/// Presentation and interaction settings for `StoryViewer`.
///
/// Independent of `StoryPlaybackConfig`, which controls timing.
@immutable
final class StoryViewerConfig {
  /// Creates a viewer configuration.
  const StoryViewerConfig({
    this.layout = StoryViewerLayout.fullscreen,
    this.backgroundColor = const Color(0xFF000000),
    this.autoplay = true,
    this.pauseInBackground = true,
    this.previousTapFraction = 0.3,
    this.longPressToPause = true,
    this.swipeBetweenGroups = true,
    this.swipeDownToDismiss = true,
    this.dismissDistance = 120,
    this.keyboardShortcuts = true,
  });

  /// Fullscreen or inline presentation.
  final StoryViewerLayout layout;

  /// Painted behind the story canvas (letterboxing).
  final Color backgroundColor;

  /// Whether playback starts as soon as the viewer appears.
  final bool autoplay;

  /// Whether playback pauses while the app is in the background.
  final bool pauseInBackground;

  /// Share of the width, from the leading edge, where a tap goes back.
  /// Taps elsewhere go forward.
  final double previousTapFraction;

  /// Whether pressing and holding pauses until release.
  final bool longPressToPause;

  /// Whether horizontal swipes move between groups.
  final bool swipeBetweenGroups;

  /// Whether dragging down calls the viewer's `onDismiss`.
  final bool swipeDownToDismiss;

  /// Downward drag distance, in logical pixels, that dismisses.
  final double dismissDistance;

  /// Whether arrow keys, space, and escape control playback.
  final bool keyboardShortcuts;

  /// Throws a [ConfigurationException] if any value is invalid.
  void validate() {
    if (!(previousTapFraction > 0 && previousTapFraction < 1)) {
      throw const ConfigurationException(
          'previousTapFraction must be between 0 and 1');
    }
    if (!(dismissDistance.isFinite && dismissDistance > 0)) {
      throw const ConfigurationException('dismissDistance must be positive');
    }
  }

  /// Returns a copy with the given fields replaced.
  StoryViewerConfig copyWith({
    StoryViewerLayout? layout,
    Color? backgroundColor,
    bool? autoplay,
    bool? pauseInBackground,
    double? previousTapFraction,
    bool? longPressToPause,
    bool? swipeBetweenGroups,
    bool? swipeDownToDismiss,
    double? dismissDistance,
    bool? keyboardShortcuts,
  }) {
    return StoryViewerConfig(
      layout: layout ?? this.layout,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      autoplay: autoplay ?? this.autoplay,
      pauseInBackground: pauseInBackground ?? this.pauseInBackground,
      previousTapFraction: previousTapFraction ?? this.previousTapFraction,
      longPressToPause: longPressToPause ?? this.longPressToPause,
      swipeBetweenGroups: swipeBetweenGroups ?? this.swipeBetweenGroups,
      swipeDownToDismiss: swipeDownToDismiss ?? this.swipeDownToDismiss,
      dismissDistance: dismissDistance ?? this.dismissDistance,
      keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryViewerConfig &&
      other.layout == layout &&
      other.backgroundColor == backgroundColor &&
      other.autoplay == autoplay &&
      other.pauseInBackground == pauseInBackground &&
      other.previousTapFraction == previousTapFraction &&
      other.longPressToPause == longPressToPause &&
      other.swipeBetweenGroups == swipeBetweenGroups &&
      other.swipeDownToDismiss == swipeDownToDismiss &&
      other.dismissDistance == dismissDistance &&
      other.keyboardShortcuts == keyboardShortcuts;

  @override
  int get hashCode => Object.hash(
        layout,
        backgroundColor,
        autoplay,
        pauseInBackground,
        previousTapFraction,
        longPressToPause,
        swipeBetweenGroups,
        swipeDownToDismiss,
        dismissDistance,
        keyboardShortcuts,
      );
}
