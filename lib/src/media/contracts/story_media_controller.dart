import 'package:meta/meta.dart';

import '../../composition/elements/story_element.dart';
import '../../core/enums/story_enums.dart';
import '../../core/errors/story_exceptions.dart';
import '../../core/models/story_source.dart';

/// An immutable snapshot of a media resource's state.
@immutable
final class StoryMediaSnapshot {
  /// Creates a snapshot.
  const StoryMediaSnapshot({
    this.status = StoryMediaStatus.uninitialized,
    this.position = Duration.zero,
    this.duration,
    this.bufferedPosition,
    this.error,
  });

  /// Lifecycle status.
  final StoryMediaStatus status;

  /// Current playback position.
  final Duration position;

  /// Total media length, once known.
  final Duration? duration;

  /// How far the media is buffered, if reported.
  final Duration? bufferedPosition;

  /// The failure behind [StoryMediaStatus.error], if any.
  final StoryException? error;

  /// Returns a copy with the given fields replaced.
  StoryMediaSnapshot copyWith({
    StoryMediaStatus? status,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    StoryException? error,
  }) {
    return StoryMediaSnapshot(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryMediaSnapshot &&
      other.status == status &&
      other.position == position &&
      other.duration == duration &&
      other.bufferedPosition == bufferedPosition &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(status, position, duration, bufferedPosition, error);

  @override
  String toString() =>
      'StoryMediaSnapshot(${status.name}, $position/${duration ?? '?'})';
}

/// Controls one piece of time-based media (a video or audio clip).
///
/// Implementations wrap a concrete player such as `video_player` or
/// `just_audio`. The playback engine depends only on this contract, never on
/// a specific media package.
///
/// **Ownership:** whoever obtains a controller from
/// [StoryMediaControllerFactory.create] owns it and must call [dispose]
/// exactly once. After [dispose], every other method throws a
/// [ControllerDisposedException].
abstract interface class StoryMediaController {
  /// The latest state.
  StoryMediaSnapshot get snapshot;

  /// Emits every state change. The stream closes on [dispose].
  Stream<StoryMediaSnapshot> get snapshots;

  /// Prepares the media. Throws a [MediaInitializationException] on failure.
  ///
  /// Calling it again after it completed has no effect.
  Future<void> initialize();

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Moves to [position], clamped to the media bounds.
  Future<void> seekTo(Duration position);

  /// Sets the speed multiplier; 1 is normal speed.
  Future<void> setPlaybackSpeed(double speed);

  /// Sets the volume between 0 and 1.
  Future<void> setVolume(double volume);

  /// Releases every resource held by this controller.
  Future<void> dispose();
}

/// Creates media controllers for the elements it supports.
///
/// Register factories with the media system to plug in a media provider.
abstract interface class StoryMediaControllerFactory {
  /// Whether this factory can play [element].
  bool supports(StoryElement element);

  /// Creates an uninitialized controller for [element].
  ///
  /// [source] is the element's source after asset references have been
  /// resolved with `StoryDocument.resolveSource`. The caller owns the result
  /// and must dispose it.
  StoryMediaController create(StoryElement element, StorySource source);
}
