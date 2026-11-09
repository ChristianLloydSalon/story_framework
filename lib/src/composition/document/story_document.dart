import 'package:meta/meta.dart';

import '../../core/errors/story_exceptions.dart';
import '../../core/models/story_source.dart';
import '../../core/utilities/json.dart';
import '../groups/story_group.dart';
import '../items/story_item.dart';
import 'story_asset.dart';
import 'story_canvas_configuration.dart';

/// The complete story project, shared by the editor, viewer, and exporter.
///
/// A document is an immutable value. Editors produce a new document for every
/// change; unchanged groups, items, and elements are shared between versions,
/// so edits are cheap.
@immutable
final class StoryDocument {
  /// Creates a document.
  StoryDocument({
    required this.id,
    this.title,
    this.revision = 0,
    this.canvas = StoryCanvasConfiguration.portrait,
    List<StoryGroup> groups = const [],
    List<StoryAsset> assets = const [],
    this.createdAt,
    this.updatedAt,
    JsonMap metadata = const {},
    JsonMap customData = const {},
  })  : groups = List.unmodifiable(groups),
        assets = List.unmodifiable(assets),
        metadata = freezeJsonMap(metadata, name: 'metadata'),
        customData = freezeJsonMap(customData, name: 'customData');

  /// Identifier of the project.
  final String id;

  /// Display title.
  final String? title;

  /// Application-managed edit counter, useful for conflict detection.
  ///
  /// This is not the serialization schema version, which the codec manages.
  final int revision;

  /// The design surface shared by every item.
  final StoryCanvasConfiguration canvas;

  /// Groups in playback order.
  final List<StoryGroup> groups;

  /// Shared media referenced by [ReferenceStorySource]s.
  final List<StoryAsset> assets;

  /// When the project was created.
  final DateTime? createdAt;

  /// When the project was last modified.
  final DateTime? updatedAt;

  /// Framework- and tool-level JSON-compatible annotations.
  final JsonMap metadata;

  /// Application-defined JSON-compatible data.
  final JsonMap customData;

  /// Every item in playback order across all groups.
  Iterable<StoryItem> get allItems => groups.expand((group) => group.items);

  /// The group with [groupId], or `null`.
  StoryGroup? groupById(String groupId) {
    for (final group in groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  /// Locates the item with [itemId], or returns `null`.
  StoryItemLocation? locateItem(String itemId) {
    for (var g = 0; g < groups.length; g++) {
      final items = groups[g].items;
      for (var i = 0; i < items.length; i++) {
        if (items[i].id == itemId) {
          return StoryItemLocation(groupIndex: g, itemIndex: i);
        }
      }
    }
    return null;
  }

  /// The item at [location], or `null` if it is out of range.
  StoryItem? itemAt(StoryItemLocation location) {
    if (location.groupIndex < 0 || location.groupIndex >= groups.length) {
      return null;
    }
    final items = groups[location.groupIndex].items;
    if (location.itemIndex < 0 || location.itemIndex >= items.length) {
      return null;
    }
    return items[location.itemIndex];
  }

  /// The asset with [assetId], or `null`.
  StoryAsset? assetById(String assetId) {
    for (final asset in assets) {
      if (asset.id == assetId) return asset;
    }
    return null;
  }

  /// Resolves [source] to a concrete location.
  ///
  /// Returns [source] unchanged unless it is a [ReferenceStorySource], in which
  /// case the referenced asset's source is returned.
  ///
  /// Throws a [StoryNotFoundException] if the referenced asset is missing.
  StorySource resolveSource(StorySource source) {
    if (source is! ReferenceStorySource) return source;
    final asset = assetById(source.assetId);
    if (asset == null) {
      throw StoryNotFoundException(
        source.assetId,
        'Document "$id" has no asset "${source.assetId}"',
      );
    }
    return asset.source;
  }

  /// Returns a copy with the given fields replaced.
  StoryDocument copyWith({
    String? id,
    String? title,
    int? revision,
    StoryCanvasConfiguration? canvas,
    List<StoryGroup>? groups,
    List<StoryAsset>? assets,
    DateTime? createdAt,
    DateTime? updatedAt,
    JsonMap? metadata,
    JsonMap? customData,
  }) {
    return StoryDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      revision: revision ?? this.revision,
      canvas: canvas ?? this.canvas,
      groups: groups ?? this.groups,
      assets: assets ?? this.assets,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      customData: customData ?? this.customData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDocument &&
          other.id == id &&
          other.title == title &&
          other.revision == revision &&
          other.canvas == canvas &&
          deepEquals(other.groups, groups) &&
          deepEquals(other.assets, assets) &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          deepEquals(other.metadata, metadata) &&
          deepEquals(other.customData, customData);

  @override
  int get hashCode => Object.hash(id, title, revision, canvas, deepHash(groups),
      deepHash(assets), createdAt, updatedAt);

  @override
  String toString() => 'StoryDocument($id, ${groups.length} groups)';
}

/// The position of an item inside a document.
@immutable
final class StoryItemLocation {
  /// Creates a location.
  const StoryItemLocation({required this.groupIndex, required this.itemIndex});

  /// Index into [StoryDocument.groups].
  final int groupIndex;

  /// Index into the group's [StoryGroup.items].
  final int itemIndex;

  @override
  bool operator ==(Object other) =>
      other is StoryItemLocation &&
      other.groupIndex == groupIndex &&
      other.itemIndex == itemIndex;

  @override
  int get hashCode => Object.hash(groupIndex, itemIndex);

  @override
  String toString() => 'StoryItemLocation($groupIndex, $itemIndex)';
}
