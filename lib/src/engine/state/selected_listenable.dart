import 'package:flutter/foundation.dart';

/// A [ValueListenable] exposing one derived value of a parent listenable,
/// notifying only when that value changes.
///
/// It subscribes to the parent only while it has listeners, so unused
/// selections never leak.
final class SelectedValueListenable<S, T> extends ChangeNotifier
    implements ValueListenable<T> {
  /// Selects a value from the `parent` listenable with `selector`.
  SelectedValueListenable(this._parent, this._selector)
      : _value = _selector(_parent.value);

  final ValueListenable<S> _parent;
  final T Function(S value) _selector;
  T _value;
  bool _subscribed = false;

  @override
  T get value => _subscribed ? _value : _selector(_parent.value);

  @override
  void addListener(VoidCallback listener) {
    if (!_subscribed) {
      _value = _selector(_parent.value);
      _parent.addListener(_onParentChanged);
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
    _parent.removeListener(_onParentChanged);
    _subscribed = false;
  }

  void _onParentChanged() {
    final next = _selector(_parent.value);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}
