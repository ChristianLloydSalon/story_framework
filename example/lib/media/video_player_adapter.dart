import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:story_framework/story_framework.dart';
import 'package:video_player/video_player.dart';

/// Plays [VideoElement]s with the `video_player` plugin.
///
/// Copy this file into your app (story_framework itself has no player
/// dependency) and pass the factory to the viewer:
///
/// ```dart
/// StoryViewer(document: doc, mediaFactories: const [VideoPlayerStoryMediaFactory()])
/// ```
final class VideoPlayerStoryMediaFactory
    implements StoryMediaControllerFactory {
  const VideoPlayerStoryMediaFactory(
      {this.headersFor, this.mixWithOthers = true});

  /// HTTP headers (for example authorization) for network videos.
  final Map<String, String>? Function(Uri url)? headersFor;

  /// Whether story audio mixes with other apps' audio.
  final bool mixWithOthers;

  @override
  bool supports(StoryElement element) => element is VideoElement;

  @override
  StoryMediaController create(StoryElement element, StorySource source) {
    final options = VideoPlayerOptions(mixWithOthers: mixWithOthers);
    final player = switch (source) {
      NetworkStorySource(:final url) => VideoPlayerController.networkUrl(
          url,
          httpHeaders: headersFor?.call(url) ?? const {},
          videoPlayerOptions: options,
        ),
      AssetStorySource(:final name, :final package) =>
        VideoPlayerController.asset(name,
            package: package, videoPlayerOptions: options),
      // Add a `FileStorySource` branch with `VideoPlayerController.file`
      // (dart:io) if your app plays local files.
      _ => throw UnsupportedStoryTypeException(
          'video_player adapter cannot play $source'),
    };
    return VideoPlayerStoryMedia(player);
  }
}

/// A [StoryVisualMediaController] over a [VideoPlayerController].
///
/// Optimized for the engine: snapshots are emitted on status changes and at
/// most every [positionInterval] for position updates (the engine
/// interpolates between them), and identical snapshots are never emitted.
final class VideoPlayerStoryMedia implements StoryVisualMediaController {
  VideoPlayerStoryMedia(
    this.player, {
    this.positionInterval = const Duration(milliseconds: 250),
  });

  /// The wrapped player.
  final VideoPlayerController player;

  /// Minimum spacing of position-only updates.
  final Duration positionInterval;

  final StreamController<StoryMediaSnapshot> _snapshots =
      StreamController.broadcast();
  StoryMediaSnapshot _snapshot = const StoryMediaSnapshot();
  Future<void>? _initialization;
  bool _disposed = false;

  @override
  StoryMediaSnapshot get snapshot => _snapshot;

  @override
  Stream<StoryMediaSnapshot> get snapshots => _snapshots.stream;

  @override
  StorySize? get naturalSize {
    final value = player.value;
    if (!value.isInitialized) return null;
    return StorySize(value.size.width, value.size.height);
  }

  @override
  Widget buildView(BuildContext context) => VideoPlayer(player);

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _publish(_snapshot.copyWith(status: StoryMediaStatus.initializing));
    player.addListener(_onValue);
    try {
      await player.initialize();
    } catch (error) {
      throw MediaInitializationException('Video failed to load', cause: error);
    }
    _onValue();
  }

  void _onValue() {
    if (_disposed) return;
    final value = player.value;
    final duration = value.duration;
    final ended = value.isInitialized &&
        duration > Duration.zero &&
        !value.isPlaying &&
        value.position >= duration;
    final status = value.hasError
        ? StoryMediaStatus.error
        : !value.isInitialized
            ? StoryMediaStatus.initializing
            : value.isBuffering
                ? StoryMediaStatus.buffering
                : ended
                    ? StoryMediaStatus.completed
                    : value.isPlaying
                        ? StoryMediaStatus.playing
                        : StoryMediaStatus.paused;
    final buffered = value.buffered.isEmpty ? null : value.buffered.last.end;
    final next = StoryMediaSnapshot(
      status: status,
      position: value.position,
      duration: value.isInitialized ? duration : null,
      bufferedPosition: buffered,
      error: value.hasError
          ? MediaInitializationException(
              value.errorDescription ?? 'Video playback failed')
          : null,
    );
    final positionOnly = next.status == _snapshot.status &&
        next.duration == _snapshot.duration &&
        next.error == _snapshot.error;
    if (positionOnly &&
        (next.position - _snapshot.position).abs() < positionInterval) {
      return;
    }
    _publish(next);
  }

  void _publish(StoryMediaSnapshot next) {
    if (next == _snapshot || _snapshots.isClosed) return;
    _snapshot = next;
    _snapshots.add(next);
  }

  void _check() {
    if (_disposed) {
      throw const ControllerDisposedException('VideoPlayerStoryMedia');
    }
  }

  @override
  Future<void> play() async {
    _check();
    await player.play();
  }

  @override
  Future<void> pause() async {
    _check();
    await player.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    _check();
    await player.seekTo(position);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _check();
    await player.setPlaybackSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    _check();
    await player.setVolume(volume);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    player.removeListener(_onValue);
    await player.dispose();
    _publish(_snapshot.copyWith(status: StoryMediaStatus.disposed));
    await _snapshots.close();
  }
}
