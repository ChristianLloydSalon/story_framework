import 'package:meta/meta.dart';

import '../../core/utilities/json.dart';
import '../items/story_item.dart';

/// An ordered collection of items, such as one user's stories.
@immutable
final class StoryGroup {
  /// Creates a group.
  StoryGroup({
    required this.id,
    this.title,
    List<StoryItem> items = const [],
    this.createdAt,
    this.expiresAt,
    JsonMap metadata = const {},
    JsonMap customData = const {},
  })  : items = List.unmodifiable(items),
        metadata = freezeJsonMap(metadata, name: 'metadata'),
        customData = freezeJsonMap(customData, name: 'customData');

  /// Identifier, unique within the document.
  final String id;

  /// Display title, such as the author's name.
  final String? title;

  /// Items in playback order.
  final List<StoryItem> items;

  /// When the group was created.
  final DateTime? createdAt;

  /// When the group stops being shown, if it expires.
  final DateTime? expiresAt;

  /// Framework- and tool-level JSON-compatible annotations.
  final JsonMap metadata;

  /// Application-defined JSON-compatible data.
  final JsonMap customData;

  /// Whether the group has expired at [now].
  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  /// The item with [itemId], or `null`.
  StoryItem? itemById(String itemId) {
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  /// Returns a copy with the given fields replaced.
  StoryGroup copyWith({
    String? id,
    String? title,
    List<StoryItem>? items,
    DateTime? createdAt,
    DateTime? expiresAt,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return StoryGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryGroup &&
          other.id == id &&
          other.title == title &&
          deepEquals(other.items, items) &&
          other.createdAt == createdAt &&
          other.expiresAt == expiresAt &&
          deepEquals(other.metadata, metadata) &&
          deepEquals(other.customData, customData);

  @override
  int get hashCode =>
      Object.hash(id, title, deepHash(items), createdAt, expiresAt);

  @override
  String toString() => 'StoryGroup($id, ${items.length} items)';
}
