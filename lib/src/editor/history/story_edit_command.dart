import 'package:meta/meta.dart';

import '../../composition/document/story_canvas_configuration.dart';
import '../../composition/document/story_document.dart';
import '../../composition/editing/document_edits.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/groups/story_group.dart';
import '../../composition/items/story_item.dart';

/// One reversible edit to a [StoryDocument].
///
/// Commands are pure: [apply] returns a new document and never mutates its
/// input. The editor keeps the document before and after each command;
/// because documents share unchanged structure, an undo step stores only the
/// changed path, not a copy of the whole document.
///
/// Implement this to add custom edits with their own undo labels.
@immutable
abstract class StoryEditCommand {
  /// Const constructor for subclasses.
  const StoryEditCommand();

  /// Short, user-facing name, such as "Move" (for "Undo Move").
  String get label;

  /// Returns [document] with the edit applied.
  StoryDocument apply(StoryDocument document);
}

/// A command defined by a function, for one-off edits.
final class StoryDocumentEdit extends StoryEditCommand {
  /// Creates a command named [label] that runs [edit].
  const StoryDocumentEdit(this.label, this.edit);

  @override
  final String label;

  /// The edit.
  final StoryDocument Function(StoryDocument document) edit;

  @override
  StoryDocument apply(StoryDocument document) => edit(document);
}

/// Adds [element] to the item with [itemId].
final class AddElementCommand extends StoryEditCommand {
  /// Creates the command; [index] is the list position (default: end).
  const AddElementCommand(this.itemId, this.element,
      {this.index, this.label = 'Add'});

  /// The target item.
  final String itemId;

  /// The element to add.
  final StoryElement element;

  /// List position, or `null` for the end.
  final int? index;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) => document.updateItem(
      itemId, (item) => item.insertElement(element, index: index));
}

/// Removes elements from the item with [itemId].
final class RemoveElementsCommand extends StoryEditCommand {
  /// Creates the command.
  const RemoveElementsCommand(this.itemId, this.elementIds,
      {this.label = 'Delete'});

  /// The target item.
  final String itemId;

  /// Elements to remove.
  final Set<String> elementIds;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.updateItem(itemId, (item) => item.removeElements(elementIds));
}

/// Replaces elements (matched by id) in the item with [itemId].
final class UpdateElementsCommand extends StoryEditCommand {
  /// Creates the command.
  const UpdateElementsCommand(this.itemId, this.elements,
      {this.label = 'Edit'});

  /// The target item.
  final String itemId;

  /// The new versions of the elements.
  final List<StoryElement> elements;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.updateItem(itemId, (item) => item.replaceElements(elements));
}

/// Sets the paint order of the item with [itemId] (bottom first).
final class ReorderLayersCommand extends StoryEditCommand {
  /// Creates the command.
  const ReorderLayersCommand(this.itemId, this.paintOrderIds,
      {this.label = 'Reorder'});

  /// The target item.
  final String itemId;

  /// Element ids from bottom to top.
  final List<String> paintOrderIds;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.updateItem(itemId, (item) => item.reorderLayers(paintOrderIds));
}

/// Replaces the item with the same id as [item].
final class UpdateItemCommand extends StoryEditCommand {
  /// Creates the command.
  const UpdateItemCommand(this.item, {this.label = 'Edit story'});

  /// The new version of the item.
  final StoryItem item;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.updateItem(item.id, (_) => item);
}

/// Inserts [item] into the group with [groupId].
final class AddItemCommand extends StoryEditCommand {
  /// Creates the command; [index] defaults to the end of the group.
  const AddItemCommand(this.groupId, this.item,
      {this.index, this.label = 'Add story'});

  /// The target group.
  final String groupId;

  /// The item to add.
  final StoryItem item;

  /// Position in the group, or `null` for the end.
  final int? index;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.insertItem(groupId, item, index: index);
}

/// Removes the item with [itemId].
final class RemoveItemCommand extends StoryEditCommand {
  /// Creates the command.
  const RemoveItemCommand(this.itemId, {this.label = 'Delete story'});

  /// The item to remove.
  final String itemId;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) => document.removeItem(itemId);
}

/// Moves the item with [itemId] to [toIndex] in the group [toGroupId].
final class MoveItemCommand extends StoryEditCommand {
  /// Creates the command.
  const MoveItemCommand(this.itemId,
      {required this.toGroupId,
      required this.toIndex,
      this.label = 'Move story'});

  /// The item to move.
  final String itemId;

  /// Destination group.
  final String toGroupId;

  /// Destination position, counted after removal.
  final int toIndex;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.moveItem(itemId, toGroupId: toGroupId, toIndex: toIndex);
}

/// Inserts [group] at [index].
final class AddGroupCommand extends StoryEditCommand {
  /// Creates the command.
  const AddGroupCommand(this.group, {this.index, this.label = 'Add group'});

  /// The group to add.
  final StoryGroup group;

  /// Position, or `null` for the end.
  final int? index;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.insertGroup(group, index: index);
}

/// Removes the group with [groupId].
final class RemoveGroupCommand extends StoryEditCommand {
  /// Creates the command.
  const RemoveGroupCommand(this.groupId, {this.label = 'Delete group'});

  /// The group to remove.
  final String groupId;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) => document.removeGroup(groupId);
}

/// Replaces the group with the same id as [group].
final class UpdateGroupCommand extends StoryEditCommand {
  /// Creates the command.
  const UpdateGroupCommand(this.group, {this.label = 'Edit group'});

  /// The new version of the group.
  final StoryGroup group;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.updateGroup(group.id, (_) => group);
}

/// Replaces the canvas configuration.
final class UpdateCanvasCommand extends StoryEditCommand {
  /// Creates the command.
  const UpdateCanvasCommand(this.canvas, {this.label = 'Edit canvas'});

  /// The new canvas.
  final StoryCanvasConfiguration canvas;

  @override
  final String label;

  @override
  StoryDocument apply(StoryDocument document) =>
      document.copyWith(canvas: canvas);
}
