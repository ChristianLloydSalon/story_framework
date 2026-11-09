import 'package:flutter/widgets.dart';

import '../../composition/items/item_timing.dart';
import '../../core/errors/story_exceptions.dart';

/// How the viewer fits into the screen.
enum StoryViewerLayout {
  /// Fills the screen; overlays avoid system UI with safe areas.
  fullscreen,

  /// Embedded in other content; overlays use the viewer's own bounds.
  inline,
}

/// Whether the viewer animates transitions and overlay changes.
enum StoryMotionPreference {
  /// Follow the platform's reduce-motion accessibility setting.
  system,

  /// Always use reduced motion.
  reduced,

  /// Always animate fully.
  full,
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
    this.itemTransition,
    this.groupTransition = const StoryTransitionConfiguration.preset(
      'cube',
      duration: Duration(milliseconds: 400),
    ),
    this.reducedMotionTransition = const StoryTransitionConfiguration.preset(
      'fade',
      duration: Duration(milliseconds: 150),
    ),
    this.motion = StoryMotionPreference.system,
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

  /// Transition between items of the same group, unless the incoming item
  /// sets its own `StoryItem.transition`. `null` cuts.
  final StoryTransitionConfiguration? itemTransition;

  /// Transition between groups. `null` cuts.
  final StoryTransitionConfiguration? groupTransition;

  /// Replaces every transition when motion is reduced. `null` cuts.
  final StoryTransitionConfiguration? reducedMotionTransition;

  /// Whether to reduce motion.
  final StoryMotionPreference motion;

  /// Whether motion is reduced in [context], following [motion].
  bool reducesMotion(BuildContext context) => switch (motion) {
        StoryMotionPreference.reduced => true,
        StoryMotionPreference.full => false,
        StoryMotionPreference.system =>
          MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      };

  /// Throws a [ConfigurationException] if any value is invalid.
  void validate() {
    if (!(previousTapFraction > 0 && previousTapFraction < 1)) {
      throw const ConfigurationException(
          'previousTapFraction must be between 0 and 1');
    }
    if (!(dismissDistance.isFinite && dismissDistance > 0)) {
      throw const ConfigurationException('dismissDistance must be positive');
    }
    for (final transition in [
      itemTransition,
      groupTransition,
      reducedMotionTransition,
    ]) {
      if (transition != null && transition.duration < Duration.zero) {
        throw const ConfigurationException(
            'Transition durations cannot be negative');
      }
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
    StoryTransitionConfiguration? itemTransition,
    StoryTransitionConfiguration? groupTransition,
    StoryTransitionConfiguration? reducedMotionTransition,
    StoryMotionPreference? motion,
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
      itemTransition: itemTransition ?? this.itemTransition,
      groupTransition: groupTransition ?? this.groupTransition,
      reducedMotionTransition:
          reducedMotionTransition ?? this.reducedMotionTransition,
      motion: motion ?? this.motion,
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
      other.keyboardShortcuts == keyboardShortcuts &&
      other.itemTransition == itemTransition &&
      other.groupTransition == groupTransition &&
      other.reducedMotionTransition == reducedMotionTransition &&
      other.motion == motion;

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
        itemTransition,
        groupTransition,
        reducedMotionTransition,
        motion,
      );
}
