import 'package:flutter/foundation.dart';

import '../core/errors/story_exceptions.dart';
import 'handlers/default_gesture_handlers.dart';
import 'story_gesture_event.dart';
import 'story_gesture_handler.dart';

/// The gesture handlers of one story surface, with enable/disable switches.
///
/// Viewer and editor surfaces each have their own registry, so their gestures
/// are configured independently.
///
/// Listeners are notified when handlers are added, replaced, removed,
/// enabled, or disabled, so the gesture layer can update its recognizers.
class StoryGestureRegistry extends ChangeNotifier {
  /// Creates a registry containing exactly [handlers].
  ///
  /// Throws a [ConfigurationException] if two handlers share an id.
  StoryGestureRegistry([
    Iterable<StoryGestureHandler> handlers = const [],
  ]) {
    handlers.forEach(register);
  }

  /// Creates a registry with the default viewer gestures:
  ///
  /// | Id | Gesture |
  /// |---|---|
  /// | `tap-navigation` | Tap leading part to go back, elsewhere to go forward |
  /// | `hold-to-pause` | Press and hold to pause |
  /// | `swipe-groups` | Horizontal swipe to change groups |
  /// | `swipe-dismiss` | Drag down to dismiss |
  ///
  /// Followed by [handlers], which take precedence on equal priority.
  factory StoryGestureRegistry.withDefaults({
    double previousTapFraction = 0.3,
    double dismissDistance = 120,
    Iterable<StoryGestureHandler> handlers = const [],
  }) =>
      StoryGestureRegistry([
        StoryTapNavigationHandler(previousFraction: previousTapFraction),
        const StoryHoldToPauseHandler(),
        const StorySwipeGroupsHandler(),
        StorySwipeDismissHandler(distance: dismissDistance),
        ...handlers,
      ]);

  final List<StoryGestureHandler> _handlers = [];
  final Set<String> _disabled = {};
  bool _disposed = false;

  /// Ids of every registered handler, in registration order.
  List<String> get ids => [for (final h in _handlers) h.id];

  /// Whether a handler with [id] is registered.
  bool contains(String id) => _indexOf(id) >= 0;

  /// Whether the handler with [id] is registered and enabled.
  bool isEnabled(String id) => contains(id) && !_disabled.contains(id);

  /// Enabled handlers in dispatch order: highest priority first, newest first
  /// on ties.
  List<StoryGestureHandler> get activeHandlers {
    final indexed = [
      for (final (index, handler) in _handlers.indexed)
        if (!_disabled.contains(handler.id)) (index, handler),
    ]..sort((a, b) {
        final byPriority = b.$2.priority.compareTo(a.$2.priority);
        return byPriority != 0 ? byPriority : b.$1.compareTo(a.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  /// Every recognizer kind requested by an enabled handler.
  Set<StoryGestureKind> get activeKinds => {
        for (final handler in activeHandlers) ...handler.kinds,
      };

  /// Adds [handler].
  ///
  /// Throws a [ConfigurationException] if its id is taken; use [replace] to
  /// swap a handler deliberately.
  void register(StoryGestureHandler handler) {
    _checkNotDisposed();
    if (contains(handler.id)) {
      throw ConfigurationException(
          'A gesture handler with id "${handler.id}" is already registered; '
          'use replace() to swap it');
    }
    _handlers.add(handler);
    notifyListeners();
  }

  /// Replaces the handler that has the same id as [handler], keeping its
  /// position and enabled state.
  ///
  /// Throws a [ConfigurationException] if no handler has that id.
  void replace(StoryGestureHandler handler) {
    _checkNotDisposed();
    final index = _indexOf(handler.id);
    if (index < 0) {
      throw ConfigurationException(
          'No gesture handler with id "${handler.id}" to replace');
    }
    _handlers[index] = handler;
    notifyListeners();
  }

  /// Removes and returns the handler with [id], or `null` if there is none.
  StoryGestureHandler? unregister(String id) {
    _checkNotDisposed();
    final index = _indexOf(id);
    if (index < 0) return null;
    _disabled.remove(id);
    final removed = _handlers.removeAt(index);
    notifyListeners();
    return removed;
  }

  /// Turns the handler with [id] on or off without removing it.
  ///
  /// Throws a [ConfigurationException] if no handler has that id.
  void setEnabled(String id, {required bool enabled}) {
    _checkNotDisposed();
    if (!contains(id)) {
      throw ConfigurationException('No gesture handler with id "$id"');
    }
    final changed = enabled ? _disabled.remove(id) : _disabled.add(id);
    if (changed) notifyListeners();
  }

  /// Offers [context]'s event to the active handlers and returns the one that
  /// handled it, or `null` if none did.
  StoryGestureHandler? dispatch(StoryGestureContext context) {
    for (final handler in activeHandlers) {
      if (!handler.kinds.contains(context.event.kind)) continue;
      if (handler.canHandle(context)) {
        handler.handle(context);
        return handler;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  int _indexOf(String id) => _handlers.indexWhere((h) => h.id == id);

  void _checkNotDisposed() {
    if (_disposed) {
      throw const ControllerDisposedException('StoryGestureRegistry');
    }
  }
}
