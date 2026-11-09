import 'package:flutter/foundation.dart';

import '../../core/models/playback_state.dart';

/// One derived value of a controller's playback state, notifying only when
/// that value changes.
///
/// Created by `StoryController.select`. It subscribes to the controller only
/// while it has listeners, so an idle selection holds no subscription. The
/// creator owns it and should [dispose] it when done.
final class StorySelection<T> extends ChangeNotifier
    implements ValueListenable<T> {
  /// Selects a value from [source] with [selector].
  StorySelection(this.source, this.selector) : _value = selector(source.value);

  /// The full playback state being selected from.
  final ValueListenable<StoryPlaybackState> source;

  /// Derives the selected value; compared with `==` to detect changes.
  final T Function(StoryPlaybackState state) selector;

  T _value;
  bool _subscribed = false;

  @override
  T get value => _subscribed ? _value : selector(source.value);

  @override
  void addListener(VoidCallback listener) {
    if (!_subscribed) {
      _value = selector(source.value);
      source.addListener(_onSourceChanged);
      _subscribed = true;
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_subscribed && !hasListeners) _unsubscribe();
  }

  @override
  void dispose() {
    if (_subscribed) _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    source.removeListener(_onSourceChanged);
    _subscribed = false;
  }

  void _onSourceChanged() {
    final next = selector(source.value);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}
