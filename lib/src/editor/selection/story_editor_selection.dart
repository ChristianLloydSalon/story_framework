import 'package:meta/meta.dart';

import '../../core/utilities/json.dart';

/// The selected elements of the item being edited.
@immutable
final class StoryEditorSelection {
  /// Creates a selection of [elementIds] (in selection order) in [itemId].
  StoryEditorSelection({this.itemId, List<String> elementIds = const []})
      : elementIds = List.unmodifiable(elementIds.toSet());

  /// Nothing selected.
  static final StoryEditorSelection empty = StoryEditorSelection();

  /// The item the selection belongs to.
  final String? itemId;

  /// Selected element ids, in the order they were selected, without
  /// duplicates.
  final List<String> elementIds;

  /// Whether nothing is selected.
  bool get isEmpty => elementIds.isEmpty;

  /// Whether exactly one element is selected.
  bool get isSingle => elementIds.length == 1;

  /// The most recently selected element, or `null`.
  String? get primary => elementIds.isEmpty ? null : elementIds.last;

  /// Whether [elementId] is selected.
  bool contains(String elementId) => elementIds.contains(elementId);

  /// Returns the selection restricted to ids that pass [keep].
  StoryEditorSelection where(bool Function(String elementId) keep) =>
      StoryEditorSelection(
          itemId: itemId, elementIds: elementIds.where(keep).toList());

  @override
  bool operator ==(Object other) =>
      other is StoryEditorSelection &&
      other.itemId == itemId &&
      deepEquals(other.elementIds, elementIds);

  @override
  int get hashCode => Object.hash(itemId, deepHash(elementIds));

  @override
  String toString() => 'StoryEditorSelection($itemId, $elementIds)';
}
