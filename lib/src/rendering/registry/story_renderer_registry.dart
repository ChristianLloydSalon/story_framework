import 'package:flutter/foundation.dart';

import '../../composition/elements/story_element.dart';
import '../../core/errors/story_exceptions.dart';
import '../contracts/story_element_renderer.dart';
import '../renderers/builtin_renderers.dart';

/// Finds the renderer for each element.
///
/// Renderers are looked up newest first: the most recently registered
/// renderer whose `supports` accepts an element wins. Register a specialized
/// renderer to take over some elements from a built-in one, or [replace] a
/// built-in by its id.
///
/// The registry owns its renderers: it disposes them when they are replaced
/// or when the registry is disposed. [unregister] hands ownership back to the
/// caller. Listeners are notified whenever the set of renderers changes, so
/// views rebuild with the new renderers.
class StoryRendererRegistry extends ChangeNotifier {
  /// Creates a registry containing exactly [renderers].
  ///
  /// Throws a [ConfigurationException] if two renderers share an id.
  StoryRendererRegistry([
    Iterable<StoryElementRenderer<StoryElement>> renderers = const [],
  ]) {
    renderers.forEach(register);
  }

  /// Creates a registry with the built-in renderers, followed by [renderers].
  ///
  /// Built-ins cover image, text, sticker, shape, drawing, and audio elements.
  /// Widget and custom elements need app-supplied renderers such as
  /// `StoryWidgetElementRenderer` and `StoryCustomElementRenderer`.
  factory StoryRendererRegistry.withDefaults([
    Iterable<StoryElementRenderer<StoryElement>> renderers = const [],
  ]) =>
      StoryRendererRegistry([...defaultStoryRenderers(), ...renderers]);

  final List<StoryElementRenderer<StoryElement>> _renderers = [];
  bool _disposed = false;

  /// Ids of the registered renderers, oldest first.
  List<String> get ids => [for (final r in _renderers) r.id];

  /// Whether a renderer with [id] is registered.
  bool contains(String id) => _indexOf(id) >= 0;

  /// Adds [renderer].
  ///
  /// Throws a [ConfigurationException] if its id is already registered; use
  /// [replace] to swap a renderer deliberately.
  void register(StoryElementRenderer<StoryElement> renderer) {
    _checkNotDisposed();
    if (contains(renderer.id)) {
      throw ConfigurationException(
          'A renderer with id "${renderer.id}" is already registered; '
          'use replace() to swap it');
    }
    _renderers.add(renderer);
    notifyListeners();
  }

  /// Replaces the renderer that has the same id as [renderer], keeping its
  /// lookup priority, and disposes the old one.
  ///
  /// Throws a [ConfigurationException] if no renderer has that id.
  void replace(StoryElementRenderer<StoryElement> renderer) {
    _checkNotDisposed();
    final index = _indexOf(renderer.id);
    if (index < 0) {
      throw ConfigurationException(
          'No renderer with id "${renderer.id}" to replace');
    }
    final previous = _renderers[index];
    _renderers[index] = renderer;
    if (!identical(previous, renderer)) previous.dispose();
    notifyListeners();
  }

  /// Removes and returns the renderer with [id], or `null` if there is none.
  ///
  /// The caller becomes responsible for disposing the returned renderer.
  StoryElementRenderer<StoryElement>? unregister(String id) {
    _checkNotDisposed();
    final index = _indexOf(id);
    if (index < 0) return null;
    final removed = _renderers.removeAt(index);
    notifyListeners();
    return removed;
  }

  /// The renderer for [element], or `null` if none supports it.
  StoryElementRenderer<StoryElement>? rendererFor(StoryElement element) {
    for (var i = _renderers.length - 1; i >= 0; i--) {
      final renderer = _renderers[i];
      if (renderer.supports(element)) return renderer;
    }
    return null;
  }

  /// The renderer for [element].
  ///
  /// Throws a [RendererNotRegisteredException] if none supports it.
  StoryElementRenderer<StoryElement> requireRendererFor(StoryElement element) {
    return rendererFor(element) ??
        (throw RendererNotRegisteredException(element.type,
            'No renderer supports ${element.type} element "${element.id}"'));
  }

  /// Disposes every registered renderer.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final renderer in _renderers) {
      renderer.dispose();
    }
    _renderers.clear();
    super.dispose();
  }

  int _indexOf(String id) => _renderers.indexWhere((r) => r.id == id);

  void _checkNotDisposed() {
    if (_disposed) {
      throw const ControllerDisposedException('StoryRendererRegistry');
    }
  }
}
