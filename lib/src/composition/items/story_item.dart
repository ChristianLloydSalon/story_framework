import 'package:meta/meta.dart';

import '../../core/utilities/json.dart';
import '../document/story_background.dart';
import '../elements/story_element.dart';
import 'item_timing.dart';

/// A single story page: a background plus layered elements.
@immutable
final class StoryItem {
  /// Creates an item.
  ///
  /// A `null` [duration] or [transition] inherits the playback configuration
  /// default.
  StoryItem({
    required this.id,
    List<StoryElement> elements = const [],
    this.background,
    this.duration,
    this.transition,
    this.playback = StoryItemPlaybackConfiguration.inherit,
    JsonMap metadata = const {},
    JsonMap customData = const {},
  })  : elements = List.unmodifiable(elements),
        metadata = freezeJsonMap(metadata, name: 'metadata'),
        customData = freezeJsonMap(customData, name: 'customData');

  /// Identifier, unique within the document.
  final String id;

  /// Elements in insertion order. See [elementsInPaintOrder].
  final List<StoryElement> elements;

  /// Background painted behind every element, or `null` for the canvas one.
  final StoryBackground? background;

  /// Display time, or `null` to use the configured default.
  final StoryItemDuration? duration;

  /// Entrance transition, or `null` to use the configured default.
  final StoryTransitionConfiguration? transition;

  /// Per-item playback overrides.
  final StoryItemPlaybackConfiguration playback;

  /// Framework- and tool-level JSON-compatible annotations.
  final JsonMap metadata;

  /// Application-defined JSON-compatible data.
  final JsonMap customData;

  /// Elements sorted by [StoryElement.zIndex], bottom first.
  ///
  /// Sorting is stable: elements with equal z-index keep their list order, so
  /// paint order is deterministic.
  List<StoryElement> get elementsInPaintOrder {
    final indexed = elements.indexed.toList()
      ..sort((a, b) {
        final byZ = a.$2.zIndex.compareTo(b.$2.zIndex);
        return byZ != 0 ? byZ : a.$1.compareTo(b.$1);
      });
    return List.unmodifiable(indexed.map((entry) => entry.$2));
  }

  /// Elements with their own timeline, such as video and audio.
  Iterable<StoryElement> get timeBasedElements =>
      elements.where((element) => element.isTimeBased);

  /// The element with [elementId], or `null`.
  StoryElement? elementById(String elementId) {
    for (final element in elements) {
      if (element.id == elementId) return element;
    }
    return null;
  }

  /// Returns a copy with the given fields replaced.
  StoryItem copyWith({
    String? id,
    List<StoryElement>? elements,
    StoryBackground? background,
    StoryItemDuration? duration,
    StoryTransitionConfiguration? transition,
    StoryItemPlaybackConfiguration? playback,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return StoryItem(
      id: id ?? this.id,
      elements: elements ?? this.elements,
      background: background ?? this.background,
      duration: duration ?? this.duration,
      transition: transition ?? this.transition,
      playback: playback ?? this.playback,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  /// Returns a copy where the element with the same id as [element] is
  /// replaced.
  ///
  /// Returns this item unchanged when no element has that id.
  StoryItem replaceElement(StoryElement element) {
    final index = elements.indexWhere((e) => e.id == element.id);
    if (index < 0) return this;
    return copyWith(elements: [...elements]..[index] = element);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryItem &&
          other.id == id &&
          deepEquals(other.elements, elements) &&
          other.background == background &&
          other.duration == duration &&
          other.transition == transition &&
          other.playback == playback &&
          deepEquals(other.metadata, metadata) &&
          deepEquals(other.customData, customData);

  @override
  int get hashCode => Object.hash(
      id, deepHash(elements), background, duration, transition, playback);

  @override
  String toString() => 'StoryItem($id, ${elements.length} elements)';
}
