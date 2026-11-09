import 'dart:async';

import 'package:story_framework/engine.dart';

/// A clock that only moves when told to.
final class FakeClock implements StoryClock {
  Duration _elapsed = Duration.zero;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration delta) => _elapsed += delta;
}

/// A ticker that fires only when [tick] is called, and only while active.
final class ManualTicker implements StoryTicker {
  ManualTicker(this._onTick);

  final void Function() _onTick;
  bool _active = false;
  bool disposed = false;

  @override
  bool get isActive => _active;

  @override
  void start() => _active = true;

  @override
  void stop() => _active = false;

  @override
  void dispose() {
    _active = false;
    disposed = true;
  }

  void tick() {
    if (_active) _onTick();
  }
}

/// Bundles a fake clock with the manual ticker the controller creates.
final class EngineHarness {
  final FakeClock clock = FakeClock();
  ManualTicker? ticker;

  StoryTicker createTicker(void Function() onTick) =>
      ticker = ManualTicker(onTick);

  /// Advances time by [delta] and fires one tick.
  void advance(Duration delta) {
    clock.advance(delta);
    ticker!.tick();
  }

  /// Advances in [step]s until [total] has elapsed, ticking after each step.
  void run(Duration total, {Duration step = const Duration(milliseconds: 16)}) {
    var remaining = total;
    while (remaining > Duration.zero) {
      final delta = remaining < step ? remaining : step;
      advance(delta);
      remaining -= delta;
    }
  }
}

/// Lets pending microtasks and zero-delay timers run.
Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A scriptable media controller that records every command.
final class FakeMediaController implements StoryMediaController {
  FakeMediaController(this.element, this.source, {this.mediaDuration});

  final StoryElement element;
  final StorySource source;
  final Duration? mediaDuration;

  final List<String> calls = [];
  final StreamController<StoryMediaSnapshot> _snapshots =
      StreamController.broadcast(sync: true);

  /// Completes initialization; replace to make it fail or hang.
  Completer<void> initialization = Completer<void>()..complete();

  StoryMediaSnapshot _snapshot = const StoryMediaSnapshot();
  bool disposed = false;

  @override
  StoryMediaSnapshot get snapshot => _snapshot;

  @override
  Stream<StoryMediaSnapshot> get snapshots => _snapshots.stream;

  /// Publishes a new state, as a real player would.
  void emit(StoryMediaSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  @override
  Future<void> initialize() async {
    calls.add('initialize');
    await initialization.future;
    _snapshot = _snapshot.copyWith(
      status: StoryMediaStatus.ready,
      duration: mediaDuration,
    );
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(Duration position) async => calls.add('seek:$position');

  @override
  Future<void> setPlaybackSpeed(double speed) async =>
      calls.add('speed:$speed');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
    await _snapshots.close();
  }
}

/// Creates [FakeMediaController]s for time-based elements and remembers them.
final class FakeMediaFactory implements StoryMediaControllerFactory {
  FakeMediaFactory({this.mediaDuration = const Duration(seconds: 10)});

  final Duration? mediaDuration;
  final List<FakeMediaController> created = [];

  /// Called on each new controller before it is returned.
  void Function(FakeMediaController controller)? onCreate;

  FakeMediaController get last => created.last;

  @override
  bool supports(StoryElement element) => element is TimedMediaElement;

  @override
  StoryMediaController create(StoryElement element, StorySource source) {
    final controller =
        FakeMediaController(element, source, mediaDuration: mediaDuration);
    onCreate?.call(controller);
    created.add(controller);
    return controller;
  }
}
