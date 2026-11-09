import 'package:flutter/foundation.dart';

import '../core/errors/story_exceptions.dart';
import 'presets/transition_presets.dart';
import 'story_transition.dart';

/// Transitions available to a viewer, looked up by id.
class StoryTransitionRegistry extends ChangeNotifier {
  /// Creates a registry containing exactly [transitions].
  ///
  /// Throws a [ConfigurationException] if two transitions share an id.
  StoryTransitionRegistry([
    Iterable<StoryTransition> transitions = const [],
  ]) {
    transitions.forEach(register);
  }

  /// Creates a registry with the built-in presets (`none`, `fade`, `slide`,
  /// `scale`, `zoom`, `cube`, `horizontalReveal`, `verticalReveal`), followed
  /// by [transitions].
  factory StoryTransitionRegistry.withDefaults([
    Iterable<StoryTransition> transitions = const [],
  ]) =>
      StoryTransitionRegistry([...storyTransitionPresets, ...transitions]);

  final Map<String, StoryTransition> _transitions = {};
  final Set<String> _reportedMissing = {};
  bool _disposed = false;

  /// Registered ids, in registration order.
  List<String> get ids => _transitions.keys.toList();

  /// Whether [id] is registered.
  bool contains(String id) => _transitions.containsKey(id);

  /// Adds [transition]; throws a [ConfigurationException] if its id is taken.
  void register(StoryTransition transition) {
    _checkNotDisposed();
    if (contains(transition.id)) {
      throw ConfigurationException(
          'A transition with id "${transition.id}" is already registered; '
          'use replace() to swap it');
    }
    _transitions[transition.id] = transition;
    notifyListeners();
  }

  /// Replaces the transition with [transition]'s id; throws a
  /// [ConfigurationException] if there is none.
  void replace(StoryTransition transition) {
    _checkNotDisposed();
    if (!contains(transition.id)) {
      throw ConfigurationException(
          'No transition with id "${transition.id}" to replace');
    }
    _transitions[transition.id] = transition;
    notifyListeners();
  }

  /// Removes and returns the transition with [id], or `null`.
  StoryTransition? unregister(String id) {
    _checkNotDisposed();
    final removed = _transitions.remove(id);
    if (removed != null) notifyListeners();
    return removed;
  }

  /// The transition with [id], or `null`.
  StoryTransition? lookup(String id) => _transitions[id];

  /// The transition with [id], or a plain cut when it is not registered.
  ///
  /// A missing id is reported once through [FlutterError.reportError], so a
  /// typo in a document never fails silently or breaks playback.
  StoryTransition resolve(String id) {
    final transition = _transitions[id];
    if (transition != null) return transition;
    if (_reportedMissing.add(id)) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: ConfigurationException(
            'No transition registered for "$id"; cutting instead'),
        library: 'story_framework',
      ));
    }
    return const StoryNoTransition();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw const ControllerDisposedException('StoryTransitionRegistry');
    }
  }
}
