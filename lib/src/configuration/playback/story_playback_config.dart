import 'package:meta/meta.dart';

import '../../core/errors/story_exceptions.dart';

/// What playback does when an item fails to load or play.
enum StoryErrorPolicy {
  /// Stop in `StoryPlaybackStatus.error` until the user retries with `play()`.
  stop,

  /// Report the error and move on to the next item.
  skip,
}

/// How far ahead the engine prepares media.
enum StoryMediaPreload {
  /// Only the current item's media is created.
  none,

  /// The next item's media is also created and initialized in advance, then
  /// reused when playback arrives, so it starts without a loading pause.
  next,
}

/// Playback behavior shared by every item in a document.
///
/// Items can override some of these values individually (see
/// `StoryItem.duration` and `StoryItem.playback`).
@immutable
final class StoryPlaybackConfig {
  /// Creates a playback configuration.
  const StoryPlaybackConfig({
    this.defaultItemDuration = const Duration(seconds: 5),
    this.autoAdvance = true,
    this.continueToNextGroup = true,
    this.loop = false,
    this.errorPolicy = StoryErrorPolicy.stop,
    this.initialPlaybackSpeed = 1,
    this.mediaPreload = StoryMediaPreload.next,
    this.maxActiveMedia = 3,
  });

  /// Display time for items without their own duration.
  final Duration defaultItemDuration;

  /// Whether playback moves to the next item when the current one ends.
  final bool autoAdvance;

  /// Whether automatic advancing crosses into the next group.
  ///
  /// When `false`, playback completes at the end of each group. Manual
  /// navigation (`next()`, `nextGroup()`) always crosses groups.
  final bool continueToNextGroup;

  /// Whether playback restarts from the first item after the last one.
  final bool loop;

  /// Handling of load and playback failures.
  final StoryErrorPolicy errorPolicy;

  /// Timeline speed multiplier at start.
  final double initialPlaybackSpeed;

  /// How far ahead media is prepared.
  final StoryMediaPreload mediaPreload;

  /// The most media controllers created per item (the duration-driving one
  /// plus companions). Preloading the next item uses the same budget, so at
  /// most twice this many controllers exist at once.
  final int maxActiveMedia;

  /// Throws a [ConfigurationException] if any value is invalid.
  void validate() {
    if (defaultItemDuration <= Duration.zero) {
      throw const ConfigurationException(
          'defaultItemDuration must be positive');
    }
    if (!(initialPlaybackSpeed.isFinite && initialPlaybackSpeed > 0)) {
      throw const ConfigurationException(
          'initialPlaybackSpeed must be a positive number');
    }
    if (maxActiveMedia < 1) {
      throw const ConfigurationException('maxActiveMedia must be at least 1');
    }
  }

  /// Returns a copy with the given fields replaced.
  StoryPlaybackConfig copyWith({
    Duration? defaultItemDuration,
    bool? autoAdvance,
    bool? continueToNextGroup,
    bool? loop,
    StoryErrorPolicy? errorPolicy,
    double? initialPlaybackSpeed,
    StoryMediaPreload? mediaPreload,
    int? maxActiveMedia,
  }) {
    return StoryPlaybackConfig(
      defaultItemDuration: defaultItemDuration ?? this.defaultItemDuration,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      continueToNextGroup: continueToNextGroup ?? this.continueToNextGroup,
      loop: loop ?? this.loop,
      errorPolicy: errorPolicy ?? this.errorPolicy,
      initialPlaybackSpeed: initialPlaybackSpeed ?? this.initialPlaybackSpeed,
      mediaPreload: mediaPreload ?? this.mediaPreload,
      maxActiveMedia: maxActiveMedia ?? this.maxActiveMedia,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryPlaybackConfig &&
      other.defaultItemDuration == defaultItemDuration &&
      other.autoAdvance == autoAdvance &&
      other.continueToNextGroup == continueToNextGroup &&
      other.loop == loop &&
      other.errorPolicy == errorPolicy &&
      other.initialPlaybackSpeed == initialPlaybackSpeed &&
      other.mediaPreload == mediaPreload &&
      other.maxActiveMedia == maxActiveMedia;

  @override
  int get hashCode => Object.hash(
      defaultItemDuration,
      autoAdvance,
      continueToNextGroup,
      loop,
      errorPolicy,
      initialPlaybackSpeed,
      mediaPreload,
      maxActiveMedia);
}
