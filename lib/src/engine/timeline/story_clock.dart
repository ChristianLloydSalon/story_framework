import 'dart:async';

/// A monotonic time source for the playback timeline.
///
/// The timeline derives positions from clock differences instead of counting
/// timer callbacks, so late or dropped ticks never accumulate drift.
abstract interface class StoryClock {
  /// Time elapsed since an arbitrary fixed origin. Never decreases.
  Duration get elapsed;
}

/// The default clock, backed by a [Stopwatch].
final class StopwatchStoryClock implements StoryClock {
  /// Creates a running clock.
  StopwatchStoryClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;
}

/// Periodically asks the controller to refresh the timeline.
///
/// Ticks only control how often progress is published; they never determine
/// the position itself. A viewer can supply a vsync-driven ticker so updates
/// line up with frames.
abstract interface class StoryTicker {
  /// Whether the ticker is currently running.
  bool get isActive;

  /// Starts ticking. Has no effect if already active.
  void start();

  /// Stops ticking. Has no effect if inactive.
  void stop();

  /// Stops ticking permanently and releases resources.
  void dispose();
}

/// Creates a [StoryTicker] that calls [onTick] while active.
typedef StoryTickerFactory = StoryTicker Function(void Function() onTick);

/// A [StoryTicker] backed by a periodic [Timer].
final class TimerStoryTicker implements StoryTicker {
  /// Creates a ticker that calls [onTick] every [interval] while active.
  TimerStoryTicker(
    this.onTick, {
    this.interval = const Duration(milliseconds: 16),
  });

  /// Called on every tick.
  final void Function() onTick;

  /// Time between ticks.
  final Duration interval;

  Timer? _timer;
  bool _disposed = false;

  @override
  bool get isActive => _timer != null;

  @override
  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
  }
}
