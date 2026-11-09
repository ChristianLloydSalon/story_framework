import 'package:meta/meta.dart';

import '../enums/story_enums.dart';
import '../errors/story_exceptions.dart';
import '../utilities/json.dart';

/// An immutable snapshot of a playback session.
@immutable
final class StoryPlaybackState {
  /// Creates a snapshot.
  StoryPlaybackState({
    this.groupIndex = 0,
    this.itemIndex = 0,
    this.position = Duration.zero,
    this.duration,
    this.status = StoryPlaybackStatus.idle,
    this.bufferingStatus = StoryBufferingStatus.ready,
    this.mediaStatus,
    Set<StoryPauseReason> pauseReasons = const {},
    this.playbackSpeed = 1,
    this.error,
  }) : pauseReasons = Set.unmodifiable(pauseReasons);

  /// The initial state before playback starts.
  factory StoryPlaybackState.initial() => StoryPlaybackState();

  /// Index of the current group.
  final int groupIndex;

  /// Index of the current item within the current group.
  final int itemIndex;

  /// Elapsed time within the current item.
  final Duration position;

  /// Total duration of the current item, or `null` when unknown or indefinite.
  final Duration? duration;

  /// Overall playback status.
  final StoryPlaybackStatus status;

  /// Whether the current item is waiting for media data.
  final StoryBufferingStatus bufferingStatus;

  /// Status of the current item's primary media, if it has any.
  final StoryMediaStatus? mediaStatus;

  /// Every reason currently holding playback.
  final Set<StoryPauseReason> pauseReasons;

  /// Timeline speed multiplier.
  final double playbackSpeed;

  /// The failure that put playback into [StoryPlaybackStatus.error], if any.
  final StoryException? error;

  /// Progress through the current item, between 0 and 1.
  ///
  /// Returns 0 when [duration] is unknown or zero.
  double get progress {
    final total = duration;
    if (total == null || total <= Duration.zero) return 0;
    return (position.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
  }

  /// Whether the timeline is advancing.
  bool get isPlaying => status == StoryPlaybackStatus.playing;

  /// Whether any pause reason is active.
  bool get isHeld => pauseReasons.isNotEmpty;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass `clearDuration` or `clearError` to reset those nullable fields.
  StoryPlaybackState copyWith({
    int? groupIndex,
    int? itemIndex,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    StoryPlaybackStatus? status,
    StoryBufferingStatus? bufferingStatus,
    StoryMediaStatus? mediaStatus,
    Set<StoryPauseReason>? pauseReasons,
    double? playbackSpeed,
    StoryException? error,
    bool clearError = false,
  }) {
    return StoryPlaybackState(
      groupIndex: groupIndex ?? this.groupIndex,
      itemIndex: itemIndex ?? this.itemIndex,
      position: position ?? this.position,
      duration: clearDuration ? null : duration ?? this.duration,
      status: status ?? this.status,
      bufferingStatus: bufferingStatus ?? this.bufferingStatus,
      mediaStatus: mediaStatus ?? this.mediaStatus,
      pauseReasons: pauseReasons ?? this.pauseReasons,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryPlaybackState &&
      other.groupIndex == groupIndex &&
      other.itemIndex == itemIndex &&
      other.position == position &&
      other.duration == duration &&
      other.status == status &&
      other.bufferingStatus == bufferingStatus &&
      other.mediaStatus == mediaStatus &&
      deepEquals(other.pauseReasons, pauseReasons) &&
      other.playbackSpeed == playbackSpeed &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
        groupIndex,
        itemIndex,
        position,
        duration,
        status,
        bufferingStatus,
        mediaStatus,
        deepHash(pauseReasons),
        playbackSpeed,
        error,
      );

  @override
  String toString() => 'StoryPlaybackState(group: $groupIndex, item: '
      '$itemIndex, ${status.name}, $position/${duration ?? '?'})';
}
