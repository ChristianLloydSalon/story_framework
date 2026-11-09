import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../composition/document/story_document.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/items/item_timing.dart';
import '../../composition/items/story_item.dart';
import '../../configuration/playback/story_playback_config.dart';
import '../../core/enums/story_enums.dart';
import '../../core/errors/story_exceptions.dart';
import '../../core/models/playback_state.dart';
import '../../media/contracts/story_media_controller.dart';
import '../playback/playback_events.dart';
import '../state/story_selection.dart';
import '../timeline/story_clock.dart';

enum _Phase { idle, loading, ready, completed, error }

/// Plays a [StoryDocument] without any UI.
///
/// The controller owns the timeline, navigation, pause reasons, and the media
/// controller of the item being played. Viewers render its [state]; apps can
/// also drive it directly for headless playback.
///
/// ```dart
/// final controller = StoryController(document: document);
/// controller.play();
/// controller.state.addListener(() => print(controller.state.value));
/// ```
///
/// **Timing.** The position is derived from a monotonic [StoryClock], never
/// from counting ticks, so it does not drift. Ticks only decide how often
/// [state] is republished.
///
/// **Asynchrony.** Navigation methods return immediately; preparing an item
/// (resolving its duration, initializing media) happens asynchronously and the
/// status moves from [StoryPlaybackStatus.loading] to playing or paused. Work
/// started for an item that is no longer current is discarded and its media is
/// disposed, so rapid navigation never produces stale updates.
///
/// **Pause reasons.** Playback advances only while no [StoryPauseReason] is
/// active. [pause] and [play] control [StoryPauseReason.user]; other reasons
/// are added and removed independently with [addPauseReason] and
/// [removePauseReason].
///
/// **Media.** Items timed by [MediaItemDuration] get a media controller from
/// the first factory in `mediaFactories` that supports the driving element.
/// The controller owns and disposes it; renderers can display it through
/// [currentMedia]. Media playback mirrors the timeline: it pauses, resumes,
/// seeks, and changes speed with it, and buffering holds the timeline.
///
/// Call [dispose] when done. Every other method then throws a
/// [ControllerDisposedException].
class StoryController {
  /// Creates a controller for [document].
  ///
  /// Starts idle at [initialLocation] (default: the first item). Nothing loads
  /// until [play] is called.
  ///
  /// Throws a [ConfigurationException] if [config] is invalid and an
  /// [ArgumentError] if [initialLocation] does not exist in [document].
  StoryController({
    required StoryDocument document,
    this.config = const StoryPlaybackConfig(),
    StoryClock? clock,
    StoryTickerFactory? tickerFactory,
    List<StoryMediaControllerFactory> mediaFactories = const [],
    Map<String, StoryDurationProvider> durationProviders = const {},
    StoryItemLocation? initialLocation,
  })  : _document = document,
        _clock = clock ?? StopwatchStoryClock(),
        _mediaFactories = List.unmodifiable(mediaFactories),
        _durationProviders = Map.unmodifiable(durationProviders),
        _speed = config.initialPlaybackSpeed {
    config.validate();
    if (initialLocation != null && document.itemAt(initialLocation) == null) {
      throw ArgumentError.value(
          initialLocation, 'initialLocation', 'No such item in the document');
    }
    _location = initialLocation ?? _firstLocation();
    _anchorTime = _clock.elapsed;
    _ticker = (tickerFactory ?? TimerStoryTicker.new)(_onTick);
    _state.value = _snapshot();
  }

  /// Playback behavior.
  final StoryPlaybackConfig config;

  final StoryDocument _document;
  final StoryClock _clock;
  final List<StoryMediaControllerFactory> _mediaFactories;
  final Map<String, StoryDurationProvider> _durationProviders;
  // Assigned once in the constructor body, which can reference `_onTick`.
  StoryTicker? _ticker;
  final ValueNotifier<StoryPlaybackState> _state =
      ValueNotifier(StoryPlaybackState.initial());
  final StreamController<StoryPlaybackEvent> _events =
      StreamController.broadcast();

  StoryItemLocation? _location;
  _Phase _phase = _Phase.idle;
  Duration? _duration;
  double _speed;
  final Set<StoryPauseReason> _reasons = {};
  StoryBufferingStatus _buffering = StoryBufferingStatus.ready;
  StoryMediaStatus? _mediaStatus;
  StoryException? _error;
  bool _heldAtEnd = false;
  int _consecutiveErrors = 0;

  // Timeline: position = anchorPosition + (now - anchorTime) * speed while
  // the timeline runs.
  Duration _anchorPosition = Duration.zero;
  Duration _anchorTime = Duration.zero;
  bool _timelineRunning = false;

  // Incremented whenever the current item changes; async work captured with an
  // older value is stale and must be discarded.
  int _generation = 0;

  StoryMediaController? _media;
  TimedMediaElement? _mediaElement;
  // Cancelled in _teardownMedia whenever the media changes or on dispose.
  // ignore: cancel_subscriptions
  StreamSubscription<StoryMediaSnapshot>? _mediaSubscription;
  bool _mediaPlaying = false;
  final Set<Future<void>> _pendingDisposals = {};

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The document being played.
  StoryDocument get document => _document;

  /// The current playback state. Notifies on every change, including progress
  /// ticks while playing.
  ///
  /// Widgets that only need part of the state should listen to [select]
  /// instead, so progress ticks do not rebuild them.
  ValueListenable<StoryPlaybackState> get state => _state;

  /// The live position, computed from the clock at the moment of the call.
  Duration get position => _currentPosition();

  /// Location of the current item, or `null` when the document has no items.
  StoryItemLocation? get location => _location;

  /// The current item, or `null` when the document has no items.
  StoryItem? get currentItem {
    final location = _location;
    return location == null ? null : _document.itemAt(location);
  }

  /// The media controller driving the current item, if any.
  ///
  /// Owned by this controller; do not dispose it. It changes when the item
  /// changes, so read it again after every location change.
  StoryMediaController? get currentMedia => _media;

  /// Moments such as items starting and completing.
  Stream<StoryPlaybackEvent> get events => _events.stream;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// A listenable for one derived value of [state] that notifies only when
  /// that value changes.
  ///
  /// ```dart
  /// final itemIndex = controller.select((state) => state.itemIndex);
  /// ```
  ///
  /// Create it once (for example in `initState`) and dispose it when done.
  StorySelection<T> select<T>(T Function(StoryPlaybackState state) selector) {
    _checkNotDisposed();
    return StorySelection<T>(_state, selector);
  }

  /// Starts or resumes playback by clearing [StoryPauseReason.user].
  ///
  /// The first call prepares the current item. After an error, retries the
  /// current item. Has no effect once playback has completed; navigate (for
  /// example with [jumpTo]) to play again.
  void play() {
    _checkNotDisposed();
    _reasons.remove(StoryPauseReason.user);
    final location = _location;
    switch (_phase) {
      case _Phase.idle:
        if (location == null) {
          _finish();
        } else {
          _enterItem(location, startAt: _anchorPosition);
        }
      case _Phase.error:
        if (location != null) _enterItem(location);
      case _Phase.loading || _Phase.ready || _Phase.completed:
        _sync();
    }
  }

  /// Pauses playback by adding [StoryPauseReason.user].
  void pause() => addPauseReason(StoryPauseReason.user);

  /// Holds playback for [reason]. Playback resumes only when every reason has
  /// been removed.
  void addPauseReason(StoryPauseReason reason) {
    _checkNotDisposed();
    if (_reasons.add(reason)) _sync();
  }

  /// Clears [reason]. Playback resumes if no other reason remains.
  void removePauseReason(StoryPauseReason reason) {
    _checkNotDisposed();
    if (_reasons.remove(reason)) _sync();
  }

  /// Moves to the next item, crossing into the next group if needed.
  ///
  /// Completes playback when called on the last item.
  void next() {
    _checkNotDisposed();
    final location = _location;
    if (location == null || _phase == _Phase.completed) return;
    if (_phase == _Phase.idle) {
      final next = _nextLocation(location);
      if (next != null) _moveIdle(next);
      return;
    }
    _advance(automatic: false);
  }

  /// Moves to the previous item, or to the last item of the previous group.
  ///
  /// Restarts the current item when it is the first one.
  void previous() {
    _checkNotDisposed();
    final location = _location;
    if (location == null) return;
    _navigate(_previousLocation(location) ?? location);
  }

  /// Moves to the first item of the next group that has items.
  ///
  /// Completes playback when there is none.
  void nextGroup() {
    _checkNotDisposed();
    final location = _location;
    if (location == null || _phase == _Phase.completed) return;
    final target = _firstItemOfGroupAfter(location.groupIndex);
    if (target != null) {
      _navigate(target);
    } else if (_phase != _Phase.idle) {
      _finish();
    }
  }

  /// Moves to the first item of the previous group that has items, or
  /// restarts the current group when it is the first.
  void previousGroup() {
    _checkNotDisposed();
    final location = _location;
    if (location == null) return;
    final target = _firstItemOfGroupBefore(location.groupIndex) ??
        StoryItemLocation(groupIndex: location.groupIndex, itemIndex: 0);
    _navigate(target);
  }

  /// Moves to the item at [location].
  ///
  /// Throws an [ArgumentError] if the item does not exist.
  void jumpTo(StoryItemLocation location) {
    _checkNotDisposed();
    if (_document.itemAt(location) == null) {
      throw ArgumentError.value(location, 'location', 'No such item');
    }
    _navigate(location);
  }

  /// Moves to the item with [itemId].
  ///
  /// Throws a [StoryNotFoundException] if no item has that id.
  void jumpToItem(String itemId) {
    _checkNotDisposed();
    final location = _document.locateItem(itemId);
    if (location == null) {
      throw StoryNotFoundException(itemId, 'No item with id "$itemId"');
    }
    _navigate(location);
  }

  /// Moves the position within the current item to [position], clamped to the
  /// item duration.
  void seekTo(Duration position) {
    _checkNotDisposed();
    if (_location == null || _phase == _Phase.completed) return;
    final target = _clamp(position);
    _anchorPosition = target;
    _anchorTime = _clock.elapsed;
    final duration = _duration;
    if (_heldAtEnd && (duration == null || target < duration)) {
      _heldAtEnd = false;
    }
    final media = _media;
    final element = _mediaElement;
    if (_phase == _Phase.ready && media != null && element != null) {
      _guard(media.seekTo(element.trimStart + target));
    }
    _sync();
  }

  /// Sets the timeline speed multiplier.
  ///
  /// Throws an [ArgumentError] unless [speed] is a positive finite number.
  void setPlaybackSpeed(double speed) {
    _checkNotDisposed();
    if (!(speed.isFinite && speed > 0)) {
      throw ArgumentError.value(speed, 'speed', 'Must be positive');
    }
    _reanchor();
    _speed = speed;
    final media = _media;
    if (media != null) _guard(media.setPlaybackSpeed(speed));
    _emit();
  }

  /// Stops playback and releases every resource, including media
  /// controllers. Completes when media disposal has finished.
  ///
  /// Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _ticker?.dispose();
    _teardownMedia();
    _state.dispose();
    unawaited(_events.close());
    await Future.wait(_pendingDisposals.toList());
  }

  // ---------------------------------------------------------------------------
  // Item lifecycle
  // ---------------------------------------------------------------------------

  void _navigate(StoryItemLocation target) {
    if (_phase == _Phase.idle) {
      _moveIdle(target);
    } else {
      _enterItem(target);
    }
  }

  void _moveIdle(StoryItemLocation target) {
    _location = target;
    _anchorPosition = Duration.zero;
    _emit();
  }

  void _enterItem(StoryItemLocation location,
      {Duration startAt = Duration.zero}) {
    final generation = ++_generation;
    _teardownMedia();
    _setTimelineRunning(false);
    final item = _document.itemAt(location);
    if (item == null) return;
    _location = location;
    _phase = _Phase.loading;
    _duration = null;
    _anchorPosition = startAt < Duration.zero ? Duration.zero : startAt;
    _anchorTime = _clock.elapsed;
    _heldAtEnd = false;
    _error = null;
    _mediaStatus = null;
    _clearBuffering();
    _emit();
    _addEvent(StoryItemStartedEvent(location));
    unawaited(_prepare(generation, item));
  }

  Future<void> _prepare(int generation, StoryItem item) async {
    final Duration? duration;
    try {
      final timing =
          item.duration ?? FixedItemDuration(config.defaultItemDuration);
      switch (timing) {
        case FixedItemDuration():
          duration = timing.duration;
        case IndefiniteItemDuration():
          duration = null;
        case CustomItemDuration():
          final provider = _durationProviders[timing.providerId];
          if (provider == null) {
            throw ConfigurationException(
                'No duration provider registered for "${timing.providerId}"');
          }
          duration = await provider.resolve(item, timing);
        case MediaItemDuration():
          duration = await _prepareMedia(generation, item, timing);
      }
    } catch (error) {
      if (_isCurrent(generation)) _handleError(error);
      return;
    }
    if (!_isCurrent(generation)) return;

    _duration = duration;
    _phase = _Phase.ready;
    _consecutiveErrors = 0;
    _anchorPosition = _clamp(_anchorPosition);
    _anchorTime = _clock.elapsed;
    _sync();
  }

  /// Creates and initializes the driving media; returns the item duration.
  Future<Duration?> _prepareMedia(
    int generation,
    StoryItem item,
    MediaItemDuration timing,
  ) async {
    final elementId = timing.elementId;
    final element = elementId == null
        ? item.timeBasedElements.firstOrNull
        : item.elementById(elementId);
    if (element is! TimedMediaElement) {
      throw PlaybackException(
          'Item "${item.id}" has no video or audio element to time it');
    }

    final factory = _mediaFactories.firstWhereOrNull(
      (candidate) => candidate.supports(element),
    );
    if (factory == null) {
      final fallback = timing.fallback;
      if (fallback != null) return _cap(fallback, timing.maxDuration);
      throw UnsupportedElementException(element.type,
          'No media controller factory supports element "${element.id}"');
    }

    final media =
        factory.create(element, _document.resolveSource(element.source));
    // Owned from here on: navigation or disposal tears it down.
    _media = media;
    _mediaElement = element;
    _mediaSubscription = media.snapshots
        .listen((snapshot) => _onMediaSnapshot(generation, snapshot));

    await media.initialize();
    if (!_isCurrent(generation)) return null;
    await media.setPlaybackSpeed(_speed);
    await media.setVolume(element.muted ? 0 : element.volume);
    final start = _anchorPosition;
    if (start > Duration.zero || element.trimStart > Duration.zero) {
      await media.seekTo(element.trimStart + start);
    }
    if (!_isCurrent(generation)) return null;

    var end = element.trimEnd;
    final length = media.snapshot.duration;
    if (length != null && (end == null || end > length)) end = length;
    var playable = end == null ? timing.fallback : end - element.trimStart;
    if (playable != null && playable < Duration.zero) playable = Duration.zero;
    return playable == null ? null : _cap(playable, timing.maxDuration);
  }

  void _onMediaSnapshot(int generation, StoryMediaSnapshot snapshot) {
    if (!_isCurrent(generation)) return;
    final element = _mediaElement;
    if (element == null) return;
    _mediaStatus = snapshot.status;

    switch (snapshot.status) {
      case StoryMediaStatus.buffering:
        _reasons.add(StoryPauseReason.buffering);
        _buffering = StoryBufferingStatus.buffering;
      case StoryMediaStatus.error:
        _handleError(snapshot.error ??
            const MediaInitializationException('Media playback failed'));
        return;
      case StoryMediaStatus.completed:
        _clearBuffering();
        if (_phase == _Phase.ready && !element.loop && !_heldAtEnd) {
          _completeItem();
          return;
        }
      case StoryMediaStatus.uninitialized ||
            StoryMediaStatus.initializing ||
            StoryMediaStatus.ready ||
            StoryMediaStatus.playing ||
            StoryMediaStatus.paused ||
            StoryMediaStatus.disposed:
        _clearBuffering();
    }

    // Follow the media clock. A looping driver wraps around, so its timeline
    // stays clock-driven and ends after one media length.
    if (_phase == _Phase.ready && !element.loop) {
      _anchorPosition = _clamp(snapshot.position - element.trimStart);
      _anchorTime = _clock.elapsed;
    }
    _sync();
  }

  void _completeItem() {
    _setTimelineRunning(false);
    _anchorPosition = _duration ?? _anchorPosition;
    final location = _location;
    if (location == null) return;
    _addEvent(StoryItemCompletedEvent(location));
    final autoAdvance = currentItem?.playback.autoAdvance ?? config.autoAdvance;
    if (autoAdvance) {
      _advance(automatic: true);
    } else {
      _heldAtEnd = true;
      _sync();
    }
  }

  void _advance({required bool automatic}) {
    final location = _location;
    if (location == null) return;
    final next = _nextLocation(location);
    final leavesGroup = next == null || next.groupIndex != location.groupIndex;
    if (automatic && leavesGroup) {
      _addEvent(StoryGroupCompletedEvent(location.groupIndex));
    }
    if (next == null ||
        (automatic && leavesGroup && !config.continueToNextGroup)) {
      _finish();
    } else {
      _enterItem(next);
    }
  }

  void _finish() {
    _addEvent(const StoryPlaybackCompletedEvent());
    final first = _firstLocation();
    if (config.loop && first != null) {
      _enterItem(first);
      return;
    }
    _generation++;
    _teardownMedia();
    _setTimelineRunning(false);
    _phase = _Phase.completed;
    _heldAtEnd = false;
    _clearBuffering();
    _emit();
  }

  void _handleError(Object error) {
    final failure = error is StoryException
        ? error
        : PlaybackException('Playback failed', cause: error);
    _addEvent(StoryPlaybackErrorEvent(failure, _location));
    _consecutiveErrors++;
    final itemCount = _document.allItems.length;
    if (config.errorPolicy == StoryErrorPolicy.skip &&
        _location != null &&
        _consecutiveErrors < itemCount) {
      _advance(automatic: true);
      return;
    }
    _generation++;
    _teardownMedia();
    _setTimelineRunning(false);
    _phase = _Phase.error;
    _error = failure;
    _clearBuffering();
    _emit();
  }

  // ---------------------------------------------------------------------------
  // Timeline
  // ---------------------------------------------------------------------------

  /// Reconciles the timeline and media with the phase and pause reasons, then
  /// publishes the state.
  void _sync() {
    if (_disposed) return;
    final ready = _phase == _Phase.ready && !_heldAtEnd;
    final blocked = _reasons.any((r) => r != StoryPauseReason.buffering);
    // Buffering holds the timeline but not the media, which must keep loading.
    final mediaShouldPlay = ready && !blocked;
    final timelineShouldRun =
        mediaShouldPlay && !_reasons.contains(StoryPauseReason.buffering);

    _setTimelineRunning(timelineShouldRun);
    final media = _media;
    if (media != null && mediaShouldPlay != _mediaPlaying) {
      _mediaPlaying = mediaShouldPlay;
      _guard(mediaShouldPlay ? media.play() : media.pause());
    }
    _emit();
  }

  void _setTimelineRunning(bool running) {
    if (running == _timelineRunning) return;
    _reanchor();
    _timelineRunning = running;
    if (running) {
      _ticker?.start();
    } else {
      _ticker?.stop();
    }
  }

  void _reanchor() {
    _anchorPosition = _currentPosition();
    _anchorTime = _clock.elapsed;
  }

  void _onTick() {
    if (_disposed || !_timelineRunning) return;
    final duration = _duration;
    if (duration != null && _currentPosition() >= duration) {
      _completeItem();
    } else {
      _emit();
    }
  }

  Duration _currentPosition() {
    var position = _anchorPosition;
    if (_timelineRunning) {
      position += _scale(_clock.elapsed - _anchorTime, _speed);
    }
    return _clamp(position);
  }

  Duration _clamp(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    final duration = _duration;
    if (duration != null && position > duration) return duration;
    return position;
  }

  static Duration _scale(Duration duration, double factor) =>
      Duration(microseconds: (duration.inMicroseconds * factor).round());

  static Duration _cap(Duration duration, Duration? max) =>
      max != null && duration > max ? max : duration;

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  StoryItemLocation? _firstLocation() => _firstItemOfGroupAfter(-1);

  StoryItemLocation? _nextLocation(StoryItemLocation location) {
    final items = _document.groups[location.groupIndex].items;
    if (location.itemIndex + 1 < items.length) {
      return StoryItemLocation(
          groupIndex: location.groupIndex, itemIndex: location.itemIndex + 1);
    }
    return _firstItemOfGroupAfter(location.groupIndex);
  }

  StoryItemLocation? _previousLocation(StoryItemLocation location) {
    if (location.itemIndex > 0) {
      return StoryItemLocation(
          groupIndex: location.groupIndex, itemIndex: location.itemIndex - 1);
    }
    for (var g = location.groupIndex - 1; g >= 0; g--) {
      final count = _document.groups[g].items.length;
      if (count > 0) {
        return StoryItemLocation(groupIndex: g, itemIndex: count - 1);
      }
    }
    return null;
  }

  StoryItemLocation? _firstItemOfGroupAfter(int groupIndex) {
    final groups = _document.groups;
    for (var g = groupIndex + 1; g < groups.length; g++) {
      if (groups[g].items.isNotEmpty) {
        return StoryItemLocation(groupIndex: g, itemIndex: 0);
      }
    }
    return null;
  }

  StoryItemLocation? _firstItemOfGroupBefore(int groupIndex) {
    for (var g = groupIndex - 1; g >= 0; g--) {
      if (_document.groups[g].items.isNotEmpty) {
        return StoryItemLocation(groupIndex: g, itemIndex: 0);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Plumbing
  // ---------------------------------------------------------------------------

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _clearBuffering() {
    _reasons.remove(StoryPauseReason.buffering);
    _buffering = StoryBufferingStatus.ready;
  }

  void _teardownMedia() {
    final subscription = _mediaSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _mediaSubscription = null;
    final media = _media;
    _media = null;
    _mediaElement = null;
    _mediaPlaying = false;
    if (media == null) return;
    final disposal = _disposeMedia(media);
    _pendingDisposals.add(disposal);
    unawaited(disposal.whenComplete(() => _pendingDisposals.remove(disposal)));
  }

  /// Disposal is deferred to a microtask: teardown often happens inside the
  /// media's own snapshot callback (completion, errors), and disposing a
  /// controller from within its own event dispatch is unsafe.
  static Future<void> _disposeMedia(StoryMediaController media) async {
    try {
      await Future<void>.microtask(() {});
      await media.dispose();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'story_framework',
        context: ErrorDescription('while disposing a media controller'),
      ));
    }
  }

  /// Runs a media command, routing failures to the error policy if the item
  /// is still current.
  void _guard(Future<void> operation) {
    final generation = _generation;
    unawaited(operation.then<void>((_) {}, onError: (Object error) {
      if (_isCurrent(generation)) _handleError(error);
    }));
  }

  StoryPlaybackState _snapshot() {
    final location = _location;
    final status = switch (_phase) {
      _Phase.idle => StoryPlaybackStatus.idle,
      _Phase.loading => StoryPlaybackStatus.loading,
      _Phase.ready => _timelineRunning
          ? StoryPlaybackStatus.playing
          : StoryPlaybackStatus.paused,
      _Phase.completed => StoryPlaybackStatus.completed,
      _Phase.error => StoryPlaybackStatus.error,
    };
    return StoryPlaybackState(
      groupIndex: location?.groupIndex ?? 0,
      itemIndex: location?.itemIndex ?? 0,
      position: _currentPosition(),
      duration: _duration,
      status: status,
      bufferingStatus: _buffering,
      mediaStatus: _mediaStatus,
      pauseReasons: _reasons,
      playbackSpeed: _speed,
      error: _error,
    );
  }

  void _emit() {
    if (_disposed) return;
    _state.value = _snapshot();
  }

  void _addEvent(StoryPlaybackEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _checkNotDisposed() {
    if (_disposed) throw const ControllerDisposedException('StoryController');
  }
}
