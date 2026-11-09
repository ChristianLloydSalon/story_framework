import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:story_framework/story_framework.dart';

/// Plays [AudioElement]s with the `just_audio` package.
///
/// Copy this file into your app (story_framework itself has no player
/// dependency) and pass the factory to the viewer.
final class JustAudioStoryMediaFactory implements StoryMediaControllerFactory {
  const JustAudioStoryMediaFactory({this.headersFor});

  /// HTTP headers (for example authorization) for network audio.
  final Map<String, String>? Function(Uri url)? headersFor;

  @override
  bool supports(StoryElement element) => element is AudioElement;

  @override
  StoryMediaController create(StoryElement element, StorySource source) {
    final loader = switch (source) {
      NetworkStorySource(:final url) => (AudioPlayer player) =>
          player.setUrl(url.toString(), headers: headersFor?.call(url)),
      AssetStorySource(:final name, :final package) => (AudioPlayer player) =>
          player.setAsset(name, package: package),
      FileStorySource(:final path) => (AudioPlayer player) =>
          player.setFilePath(path),
      _ => throw UnsupportedStoryTypeException(
          'just_audio adapter cannot play $source'),
    };
    return JustAudioStoryMedia(AudioPlayer(), loader);
  }
}

/// A [StoryMediaController] over a just_audio [AudioPlayer].
///
/// Emits snapshots on state changes and throttles position-only updates to
/// [positionInterval]; the engine interpolates between them.
final class JustAudioStoryMedia implements StoryMediaController {
  JustAudioStoryMedia(
    this.player,
    this._load, {
    this.positionInterval = const Duration(milliseconds: 250),
  });

  /// The wrapped player.
  final AudioPlayer player;

  final Future<Duration?> Function(AudioPlayer player) _load;

  /// Minimum spacing of position-only updates.
  final Duration positionInterval;

  final StreamController<StoryMediaSnapshot> _snapshots =
      StreamController.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  StoryMediaSnapshot _snapshot = const StoryMediaSnapshot();
  Future<void>? _initialization;
  bool _disposed = false;

  @override
  StoryMediaSnapshot get snapshot => _snapshot;

  @override
  Stream<StoryMediaSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _publish(_snapshot.copyWith(status: StoryMediaStatus.initializing));
    _subscriptions
      ..add(player.playerStateStream.listen((_) => _update()))
      ..add(player.positionStream.listen((_) => _update()))
      ..add(player.durationStream.listen((_) => _update()));
    try {
      await _load(player);
    } catch (error) {
      throw MediaInitializationException('Audio failed to load', cause: error);
    }
    _update();
  }

  void _update() {
    if (_disposed) return;
    final state = player.playerState;
    final status = switch (state.processingState) {
      ProcessingState.idle => StoryMediaStatus.initializing,
      ProcessingState.loading => StoryMediaStatus.initializing,
      ProcessingState.buffering => StoryMediaStatus.buffering,
      ProcessingState.completed => StoryMediaStatus.completed,
      ProcessingState.ready =>
        state.playing ? StoryMediaStatus.playing : StoryMediaStatus.paused,
    };
    final next = StoryMediaSnapshot(
      status: status,
      position: player.position,
      duration: player.duration,
      bufferedPosition: player.bufferedPosition,
    );
    final positionOnly =
        next.status == _snapshot.status && next.duration == _snapshot.duration;
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
      throw const ControllerDisposedException('JustAudioStoryMedia');
    }
  }

  @override
  Future<void> play() async {
    _check();
    // just_audio's play() completes when playback stops; do not wait for it.
    unawaited(player.play());
  }

  @override
  Future<void> pause() async {
    _check();
    await player.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    _check();
    await player.seek(position);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _check();
    await player.setSpeed(speed);
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
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    _publish(_snapshot.copyWith(status: StoryMediaStatus.disposed));
    await _snapshots.close();
  }
}
