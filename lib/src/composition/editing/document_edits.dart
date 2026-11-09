import '../../core/errors/story_exceptions.dart';
import '../document/story_document.dart';
import '../elements/story_element.dart';
import '../groups/story_group.dart';
import '../items/story_item.dart';

/// Immutable editing operations on a [StoryDocument].
///
/// Every operation returns a new document and shares every untouched group,
/// item, and element with the original, so keeping old versions (for undo)
/// costs only the changed path. Operations on a missing id throw a
/// [StoryNotFoundException].
extension StoryDocumentEditing on StoryDocument {
  /// The item with [itemId], or `null`.
  StoryItem? itemById(String itemId) {
    final location = locateItem(itemId);
    return location == null ? null : itemAt(location);
  }

  /// The group containing the item with [itemId], or `null`.
  StoryGroup? groupOfItem(String itemId) {
    final location = locateItem(itemId);
    return location == null ? null : groups[location.groupIndex];
  }

  /// Replaces the item with [itemId] by `update(item)`.
  StoryDocument updateItem(
    String itemId,
    StoryItem Function(StoryItem item) update,
  ) {
    final location = _requireItem(itemId);
    final group = groups[location.groupIndex];
    final items = [...group.items];
    items[location.itemIndex] = update(items[location.itemIndex]);
    return _replaceGroup(location.groupIndex, group.copyWith(items: items));
  }

  /// Inserts [item] into the group with [groupId] at [index] (default: end).
  StoryDocument insertItem(String groupId, StoryItem item, {int? index}) {
    final groupIndex = _requireGroup(groupId);
    final group = groups[groupIndex];
    final items = [...group.items];
    items.insert((index ?? items.length).clamp(0, items.length), item);
    return _replaceGroup(groupIndex, group.copyWith(items: items));
  }

  /// Removes the item with [itemId].
  StoryDocument removeItem(String itemId) {
    final location = _requireItem(itemId);
    final group = groups[location.groupIndex];
    final items = [...group.items]..removeAt(location.itemIndex);
    return _replaceGroup(location.groupIndex, group.copyWith(items: items));
  }

  /// Moves the item with [itemId] into the group with [toGroupId] at
  /// [toIndex], counted after the item has been removed from its old place.
  StoryDocument moveItem(
    String itemId, {
    required String toGroupId,
    required int toIndex,
  }) {
    final location = _requireItem(itemId);
    final item = groups[location.groupIndex].items[location.itemIndex];
    _requireGroup(toGroupId);
    return removeItem(itemId).insertItem(toGroupId, item, index: toIndex);
  }

  /// Replaces the group with [groupId] by `update(group)`.
  StoryDocument updateGroup(
    String groupId,
    StoryGroup Function(StoryGroup group) update,
  ) {
    final index = _requireGroup(groupId);
    return _replaceGroup(index, update(groups[index]));
  }

  /// Inserts [group] at [index] (default: end).
  StoryDocument insertGroup(StoryGroup group, {int? index}) {
    final next = [...groups];
    next.insert((index ?? next.length).clamp(0, next.length), group);
    return copyWith(groups: next);
  }

  /// Removes the group with [groupId].
  StoryDocument removeGroup(String groupId) {
    final index = _requireGroup(groupId);
    return copyWith(groups: [...groups]..removeAt(index));
  }

  /// Moves the group with [groupId] to [toIndex].
  StoryDocument moveGroup(String groupId, int toIndex) {
    final index = _requireGroup(groupId);
    final next = [...groups];
    final group = next.removeAt(index);
    next.insert(toIndex.clamp(0, next.length), group);
    return copyWith(groups: next);
  }

  StoryDocument _replaceGroup(int index, StoryGroup group) {
    final next = [...groups];
    next[index] = group;
    return copyWith(groups: next);
  }

  StoryItemLocation _requireItem(String itemId) =>
      locateItem(itemId) ??
      (throw StoryNotFoundException(itemId, 'No item with id "$itemId"'));

  int _requireGroup(String groupId) {
    final index = groups.indexWhere((group) => group.id == groupId);
    if (index < 0) {
      throw StoryNotFoundException(groupId, 'No group with id "$groupId"');
    }
    return index;
  }
}

/// Immutable editing operations on a [StoryItem]'s elements.
extension StoryItemEditing on StoryItem {
  /// Inserts [element] at [index] in the list (default: end).
  ///
  /// Throws an [EditorOperationException] if the id is already used.
  StoryItem insertElement(StoryElement element, {int? index}) {
    if (elementById(element.id) != null) {
      throw EditorOperationException(
          'Item "$id" already has an element "${element.id}"');
    }
    final next = [...elements];
    next.insert((index ?? next.length).clamp(0, next.length), element);
    return copyWith(elements: next);
  }

  /// Removes the elements whose ids are in [ids].
  StoryItem removeElements(Set<String> ids) => copyWith(elements: [
        for (final e in elements)
          if (!ids.contains(e.id)) e
      ]);

  /// Replaces elements that share an id with one of [updated].
  StoryItem replaceElements(Iterable<StoryElement> updated) {
    final byId = {for (final element in updated) element.id: element};
    if (byId.isEmpty) return this;
    return copyWith(elements: [
      for (final element in elements) byId[element.id] ?? element,
    ]);
  }

  /// Reorders elements so that [paintOrderIds] (bottom first) becomes the
  /// paint order, and renumbers z-indexes to match list positions.
  ///
  /// Elements missing from [paintOrderIds] keep their relative order below
  /// the listed ones. The result has a deterministic paint order with
  /// `zIndex == list index` for every element.
  StoryItem reorderLayers(List<String> paintOrderIds) {
    final listed = paintOrderIds.toSet();
    final unlisted = [
      for (final element in elementsInPaintOrder)
        if (!listed.contains(element.id)) element,
    ];
    final ordered = [
      ...unlisted,
      for (final id in paintOrderIds)
        if (elementById(id) case final element?) element,
    ];
    return copyWith(elements: [
      for (final (index, element) in ordered.indexed)
        element.zIndex == index
            ? element
            : element.copyWithCommon(zIndex: index),
    ]);
  }
}
