import 'package:flutter/foundation.dart';

import '../../composition/document/story_background.dart';
import '../../composition/document/story_document.dart';
import '../../composition/editing/document_edits.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/elements/story_transform.dart';
import '../../composition/groups/story_group.dart';
import '../../composition/items/item_timing.dart';
import '../../composition/items/story_item.dart';
import '../../composition/validation/story_document_validator.dart';
import '../../configuration/editor/story_editor_config.dart';
import '../../core/errors/story_exceptions.dart';
import '../../core/models/geometry.dart';
import '../../core/models/story_color.dart';
import '../geometry/element_geometry.dart';
import '../geometry/story_snapping.dart';
import '../history/story_edit_command.dart';
import '../history/story_edit_history.dart';
import '../selection/story_editor_selection.dart';
import 'story_id_generator.dart';

/// Brush settings for the drawing tool.
@immutable
final class StoryBrush {
  /// Creates brush settings.
  const StoryBrush({
    this.color = StoryColor.white,
    this.width = 12,
    this.opacity = 1,
  });

  /// Stroke color.
  final StoryColor color;

  /// Stroke width in canvas units.
  final double width;

  /// Stroke opacity between 0 and 1.
  final double opacity;

  /// Returns a copy with the given fields replaced.
  StoryBrush copyWith({StoryColor? color, double? width, double? opacity}) =>
      StoryBrush(
        color: color ?? this.color,
        width: width ?? this.width,
        opacity: opacity ?? this.opacity,
      );

  @override
  bool operator ==(Object other) =>
      other is StoryBrush &&
      other.color == color &&
      other.width == width &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(color, width, opacity);
}

/// How [StoryEditorController.alignSelection] lines elements up.
enum StoryAlignment {
  /// Left edges.
  left,

  /// Horizontal centers.
  centerHorizontal,

  /// Right edges.
  right,

  /// Top edges.
  top,

  /// Vertical centers.
  centerVertical,

  /// Bottom edges.
  bottom,
}

/// The axis [StoryEditorController.distributeSelection] spaces along.
enum StoryDistribution {
  /// Equal horizontal spacing of centers.
  horizontal,

  /// Equal vertical spacing of centers.
  vertical,
}

/// Edits a [StoryDocument]: selection, element and layer operations, story
/// items, transactions, and undo/redo.
///
/// The controller is independent of any widget and of playback, so it can
/// drive the default `StoryEditor`, a custom editing UI, or tests.
///
/// **Edits.** Every change goes through [execute] with a
/// [StoryEditCommand], producing one undo step labeled with the command.
/// Group continuous interactions (a drag, a typed word) into one step with
/// [beginTransaction] and [commitTransaction], or [runTransaction].
///
/// **Current item.** Element operations apply to [currentItem], the item
/// shown on the canvas.
///
/// **Locked elements** cannot be moved, transformed, deleted, or duplicated
/// through selection operations, and are not selectable on the canvas.
///
/// **State outside the document.** Guides, the marquee, and brush settings
/// live in separate listenables, so they never create undo steps. The canvas
/// viewport (zoom and pan) is owned by the canvas widget.
class StoryEditorController extends ChangeNotifier {
  /// Creates a controller editing [document], or a new blank document.
  StoryEditorController({
    StoryDocument? document,
    this.config = const StoryEditorConfig(),
    StoryIdGenerator? idGenerator,
    this.validator = const StoryDocumentValidator(),
    this.onDocumentChanged,
  })  : ids = idGenerator ?? RandomStoryIdGenerator(),
        _history = StoryEditHistory(limit: config.historyLimit),
        _document = document ?? StoryDocument(id: 'story') {
    config.validate();
    if (document == null) _document = _blankDocument();
    _currentItemId = _document.allItems.firstOrNull?.id;
    _selection = StoryEditorSelection(itemId: _currentItemId);
  }

  /// Editing behavior.
  final StoryEditorConfig config;

  /// Creates ids for new content.
  final StoryIdGenerator ids;

  /// Validates the document after edits (see [StoryEditorConfig.validation]).
  final StoryDocumentValidator validator;

  /// Called with the new document after every change, including undo and
  /// redo.
  final ValueChanged<StoryDocument>? onDocumentChanged;

  /// Alignment guides to draw while snapping. Not part of the document.
  final ValueNotifier<List<StoryGuide>> guides = ValueNotifier(const []);

  /// The drag-selection rectangle in canvas units, or `null`.
  final ValueNotifier<StoryRect?> marquee = ValueNotifier(null);

  /// Drawing tool settings.
  final ValueNotifier<StoryBrush> brush = ValueNotifier(const StoryBrush());

  final StoryEditHistory _history;
  StoryDocument _document;
  String? _currentItemId;
  StoryEditorSelection _selection = StoryEditorSelection.empty;
  String _activeToolId = 'select';
  String? _editingTextId;
  StoryValidationResult? _lastValidation;
  _Transaction? _transaction;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The document being edited.
  StoryDocument get document => _document;

  /// Id of the item shown on the canvas.
  String? get currentItemId => _currentItemId;

  /// The item shown on the canvas.
  StoryItem? get currentItem {
    final id = _currentItemId;
    return id == null ? null : _document.itemById(id);
  }

  /// The group containing [currentItem].
  StoryGroup? get currentGroup {
    final id = _currentItemId;
    return id == null ? null : _document.groupOfItem(id);
  }

  /// The current selection.
  StoryEditorSelection get selection => _selection;

  /// Selected elements of the current item, in selection order.
  List<StoryElement> get selectedElements {
    final item = currentItem;
    if (item == null) return const [];
    return [
      for (final id in _selection.elementIds)
        if (item.elementById(id) case final element?) element,
    ];
  }

  /// Selected elements that are not locked.
  List<StoryElement> get editableSelection => [
        for (final e in selectedElements)
          if (!e.locked) e
      ];

  /// The active tool id.
  String get activeToolId => _activeToolId;

  /// The text element being edited inline, if any.
  String? get editingTextId => _editingTextId;

  /// The result of the last validation, when validation is enabled.
  StoryValidationResult? get lastValidation => _lastValidation;

  /// Whether [undo] would do something.
  bool get canUndo => _history.canUndo;

  /// Whether [redo] would do something.
  bool get canRedo => _history.canRedo;

  /// The label of the step [undo] would revert.
  String? get undoLabel => _history.undoLabel;

  /// The label of the step [redo] would reapply.
  String? get redoLabel => _history.redoLabel;

  /// Whether a transaction is open.
  bool get isInTransaction => _transaction != null;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// A new id with [prefix] that no element of the current item uses.
  String newId(String prefix) {
    final item = currentItem;
    var id = ids.next(prefix);
    while (item != null && item.elementById(id) != null) {
      id = ids.next(prefix);
    }
    return id;
  }

  // ---------------------------------------------------------------------------
  // Documents and items
  // ---------------------------------------------------------------------------

  /// Replaces the document and forgets history.
  void load(StoryDocument document) {
    _checkNotDisposed();
    _finishTransactionSilently();
    _document = document;
    _currentItemId = document.allItems.firstOrNull?.id;
    _selection = StoryEditorSelection(itemId: _currentItemId);
    _editingTextId = null;
    _history.clear();
    _changed(documentChanged: true);
  }

  /// Shows the item with [itemId] on the canvas and clears the selection.
  void setCurrentItem(String itemId) {
    _checkNotDisposed();
    if (_document.itemById(itemId) == null) {
      throw StoryNotFoundException(itemId, 'No item with id "$itemId"');
    }
    if (_currentItemId == itemId) return;
    _currentItemId = itemId;
    _selection = StoryEditorSelection(itemId: itemId);
    _editingTextId = null;
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Commands, transactions, history
  // ---------------------------------------------------------------------------

  /// Applies [command] as one undo step (or as part of the open transaction).
  ///
  /// [selectAfter] replaces the selection; ids that no longer exist are
  /// dropped. Throws an [EditorOperationException] when the command fails,
  /// or when [StoryEditValidation.reject] is configured and the result has
  /// validation errors; the document is then unchanged.
  void execute(StoryEditCommand command, {StoryEditorSelection? selectAfter}) {
    _checkNotDisposed();
    final before = _document;
    final StoryDocument after;
    try {
      after = command.apply(before);
    } on StoryException {
      rethrow;
    } catch (error) {
      throw EditorOperationException('"${command.label}" failed', cause: error);
    }
    final selectionBefore = _selection;
    final selectionAfter = _sanitize(selectAfter ?? _selection, after);
    if (after == before && selectionAfter == selectionBefore) return;

    if (config.validation != StoryEditValidation.none) {
      final result = validator.validate(after);
      if (config.validation == StoryEditValidation.reject && !result.isValid) {
        throw EditorOperationException(
          '"${command.label}" would make the story invalid',
          cause: InvalidCompositionException(result.issues),
        );
      }
      _lastValidation = result;
    }

    _document = after;
    _selection = selectionAfter;
    if (_currentItemId case final id? when after.itemById(id) == null) {
      _currentItemId = after.allItems.firstOrNull?.id;
      _selection = StoryEditorSelection(itemId: _currentItemId);
    }
    final transaction = _transaction;
    if (transaction == null) {
      if (after != before) {
        _history.push(StoryHistoryEntry(
          label: command.label,
          before: before,
          after: after,
          selectionBefore: selectionBefore,
          selectionAfter: _selection,
        ));
      }
    } else {
      transaction.touched = true;
    }
    _changed(documentChanged: after != before);
  }

  /// Starts grouping edits into one undo step named [label].
  ///
  /// Transactions nest; only the outermost commit records a step.
  void beginTransaction(String label) {
    _checkNotDisposed();
    final open = _transaction;
    if (open != null) {
      open.depth++;
      return;
    }
    _transaction = _Transaction(label, _document, _selection, _currentItemId);
  }

  /// Ends the current transaction and records its edits as one undo step.
  void commitTransaction() {
    final transaction = _transaction;
    if (transaction == null) return;
    if (transaction.depth > 0) {
      transaction.depth--;
      return;
    }
    _transaction = null;
    if (_document != transaction.document) {
      _history.push(StoryHistoryEntry(
        label: transaction.label,
        before: transaction.document,
        after: _document,
        selectionBefore: transaction.selection,
        selectionAfter: _selection,
      ));
      _changed();
    }
  }

  /// Ends the current transaction and reverts its edits.
  void cancelTransaction() {
    final transaction = _transaction;
    if (transaction == null) return;
    _transaction = null;
    final changed = _document != transaction.document;
    _document = transaction.document;
    _selection = transaction.selection;
    _currentItemId = transaction.currentItemId;
    if (changed || transaction.touched) _changed(documentChanged: changed);
  }

  /// Runs [edits] as one undo step named [label]. If [edits] throws, its
  /// changes are reverted and the error is rethrown.
  void runTransaction(String label, void Function() edits) {
    beginTransaction(label);
    try {
      edits();
    } catch (_) {
      cancelTransaction();
      rethrow;
    }
    commitTransaction();
  }

  /// Reverts the latest step. An open transaction is committed first.
  void undo() {
    _checkNotDisposed();
    _finishTransactionSilently();
    final entry = _history.undo();
    if (entry == null) return;
    _restore(entry.before, entry.selectionBefore);
  }

  /// Reapplies the latest undone step.
  void redo() {
    _checkNotDisposed();
    _finishTransactionSilently();
    final entry = _history.redo();
    if (entry == null) return;
    _restore(entry.after, entry.selectionAfter);
  }

  /// Forgets every undo and redo step.
  void clearHistory() {
    _history.clear();
    _changed();
  }

  void _restore(StoryDocument document, StoryEditorSelection selection) {
    _document = document;
    final itemId = selection.itemId;
    if (itemId != null && document.itemById(itemId) != null) {
      _currentItemId = itemId;
    } else if (_currentItemId case final id?
        when document.itemById(id) == null) {
      _currentItemId = document.allItems.firstOrNull?.id;
    }
    _selection = _sanitize(selection, document);
    _editingTextId = null;
    if (config.validation != StoryEditValidation.none) {
      _lastValidation = validator.validate(document);
    }
    _changed(documentChanged: true);
  }

  void _finishTransactionSilently() {
    while (_transaction != null) {
      commitTransaction();
    }
  }

  // ---------------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------------

  /// Selects [elementIds] in the current item, replacing or extending the
  /// selection.
  void select(Iterable<String> elementIds, {bool additive = false}) {
    _checkNotDisposed();
    final next = StoryEditorSelection(
      itemId: _currentItemId,
      elementIds: [if (additive) ..._selection.elementIds, ...elementIds],
    );
    _setSelection(next);
  }

  /// Adds [elementId] to the selection, or removes it if selected.
  void toggleSelection(String elementId) {
    _checkNotDisposed();
    if (_selection.contains(elementId)) {
      _setSelection(_selection.where((id) => id != elementId));
    } else {
      select([elementId], additive: true);
    }
  }

  /// Selects every visible, unlocked element of the current item.
  void selectAll() {
    final item = currentItem;
    if (item == null) return;
    select([
      for (final e in item.elementsInPaintOrder)
        if (e.visible && !e.locked) e.id,
    ]);
  }

  /// Clears the selection.
  void clearSelection() =>
      _setSelection(StoryEditorSelection(itemId: _currentItemId));

  /// Selects visible, unlocked elements overlapping [rect] (canvas units).
  void selectInRect(StoryRect rect, {bool additive = false}) {
    final item = currentItem;
    if (item == null) return;
    select(
      [for (final e in StoryElementGeometry.elementsInRect(item, rect)) e.id],
      additive: additive,
    );
  }

  void _setSelection(StoryEditorSelection selection) {
    final next = _sanitize(selection, _document);
    if (next == _selection) return;
    _selection = next;
    final editing = _editingTextId;
    if (editing != null && !next.contains(editing)) _editingTextId = null;
    _changed();
  }

  StoryEditorSelection _sanitize(
      StoryEditorSelection selection, StoryDocument document) {
    final itemId = selection.itemId ?? _currentItemId;
    final item = itemId == null ? null : document.itemById(itemId);
    if (item == null) return StoryEditorSelection(itemId: itemId);
    return StoryEditorSelection(
      itemId: itemId,
      elementIds: [
        for (final id in selection.elementIds)
          if (item.elementById(id) != null) id,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Elements
  // ---------------------------------------------------------------------------

  /// The element with [elementId] in the current item.
  StoryElement? elementById(String elementId) =>
      currentItem?.elementById(elementId);

  String _requireCurrentItemId() =>
      _currentItemId ?? (throw const EditorOperationException('No story item'));

  /// Adds [element] on top of the current item and, by default, selects it.
  void addElement(StoryElement element,
      {bool select = true, String label = 'Add'}) {
    final itemId = _requireCurrentItemId();
    final item = currentItem;
    final top = item == null || item.elements.isEmpty
        ? 0
        : item.elements.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b) +
            1;
    final placed =
        element.zIndex >= top ? element : element.copyWithCommon(zIndex: top);
    execute(
      AddElementCommand(itemId, placed, label: label),
      selectAfter: select
          ? StoryEditorSelection(itemId: itemId, elementIds: [element.id])
          : null,
    );
  }

  /// Replaces the element with the same id as [element].
  void updateElement(StoryElement element, {String label = 'Edit'}) =>
      updateElements([element], label: label);

  /// Replaces several elements in one step.
  void updateElements(List<StoryElement> elements, {String label = 'Edit'}) {
    if (elements.isEmpty) return;
    execute(
        UpdateElementsCommand(_requireCurrentItemId(), elements, label: label));
  }

  /// Deletes the selected, unlocked elements.
  void deleteSelection() {
    final targets = editableSelection;
    if (targets.isEmpty) return;
    execute(
      RemoveElementsCommand(
          _requireCurrentItemId(), {for (final e in targets) e.id}),
      selectAfter: StoryEditorSelection(itemId: _currentItemId),
    );
  }

  /// Duplicates the selected, unlocked elements, offset by
  /// [StoryEditorConfig.duplicateOffset], and selects the copies.
  void duplicateSelection() {
    final targets = editableSelection;
    final item = currentItem;
    if (targets.isEmpty || item == null) return;
    final itemId = _requireCurrentItemId();
    var top =
        item.elements.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b);
    final copies = <StoryElement>[];
    runTransaction('Duplicate', () {
      for (final element in targets) {
        final copy = _withId(element, newId(element.type)).copyWithCommon(
          transform: element.transform.translate(config.duplicateOffset),
          zIndex: ++top,
        );
        copies.add(copy);
        execute(AddElementCommand(itemId, copy));
      }
      _setSelection(StoryEditorSelection(
          itemId: itemId, elementIds: [for (final c in copies) c.id]));
    });
  }

  /// Moves the selected, unlocked elements by [delta] canvas units.
  void moveSelection(StoryPoint delta, {String label = 'Move'}) {
    final targets = editableSelection;
    if (targets.isEmpty || delta == StoryPoint.zero) return;
    updateElements([
      for (final e in targets)
        e.copyWithCommon(transform: e.transform.translate(delta)),
    ], label: label);
  }

  /// Moves the selection by one nudge step (or a large one).
  void nudgeSelection(double dx, double dy, {bool large = false}) {
    final step = large ? config.largeNudgeDistance : config.nudgeDistance;
    moveSelection(StoryPoint(dx * step, dy * step), label: 'Nudge');
  }

  /// Locks or unlocks the selected elements.
  void setSelectionLocked(bool locked) {
    updateElements([
      for (final e in selectedElements)
        if (e.locked != locked) e.copyWithCommon(locked: locked),
    ], label: locked ? 'Lock' : 'Unlock');
  }

  /// Shows or hides the selected elements.
  void setSelectionVisible(bool visible) {
    updateElements([
      for (final e in selectedElements)
        if (e.visible != visible) e.copyWithCommon(visible: visible),
    ], label: visible ? 'Show' : 'Hide');
  }

  /// Toggles whether the element with [elementId] is locked.
  void toggleLocked(String elementId) {
    final element = elementById(elementId);
    if (element == null) return;
    updateElement(element.copyWithCommon(locked: !element.locked),
        label: element.locked ? 'Unlock' : 'Lock');
  }

  /// Toggles whether the element with [elementId] is visible.
  void toggleVisible(String elementId) {
    final element = elementById(elementId);
    if (element == null) return;
    updateElement(element.copyWithCommon(visible: !element.visible),
        label: element.visible ? 'Hide' : 'Show');
  }

  /// Sets the display name of the element with [elementId] (stored in its
  /// `metadata['name']`).
  void renameElement(String elementId, String name) {
    final element = elementById(elementId);
    if (element == null) return;
    final metadata = {...element.metadata};
    if (name.trim().isEmpty) {
      metadata.remove('name');
    } else {
      metadata['name'] = name.trim();
    }
    updateElement(element.copyWithCommon(metadata: metadata), label: 'Rename');
  }

  /// Mirrors the selected, unlocked elements.
  void flipSelection({required bool horizontal}) {
    updateElements([
      for (final e in editableSelection)
        e.copyWithCommon(
          transform: horizontal
              ? e.transform
                  .copyWith(flipHorizontal: !e.transform.flipHorizontal)
              : e.transform.copyWith(flipVertical: !e.transform.flipVertical),
        ),
    ], label: 'Flip');
  }

  // ---------------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------------

  /// Element ids of the current item in paint order, bottom first.
  List<String> get layerOrder => [
        for (final e
            in currentItem?.elementsInPaintOrder ?? const <StoryElement>[])
          e.id
      ];

  /// Moves the selection one layer up.
  void bringForward() => _shiftLayers(up: true);

  /// Moves the selection one layer down.
  void sendBackward() => _shiftLayers(up: false);

  /// Moves the selection to the top.
  void bringToFront() {
    final selected = _selectedInPaintOrder();
    if (selected.isEmpty) return;
    _setLayers(
        [...layerOrder.where((id) => !selected.contains(id)), ...selected],
        'Bring to front');
  }

  /// Moves the selection to the bottom.
  void sendToBack() {
    final selected = _selectedInPaintOrder();
    if (selected.isEmpty) return;
    _setLayers(
        [...selected, ...layerOrder.where((id) => !selected.contains(id))],
        'Send to back');
  }

  /// Moves the element with [elementId] to [paintIndex] (0 = bottom).
  void reorderLayer(String elementId, int paintIndex) {
    final order = layerOrder;
    if (!order.remove(elementId)) return;
    order.insert(paintIndex.clamp(0, order.length), elementId);
    _setLayers(order, 'Reorder');
  }

  List<String> _selectedInPaintOrder() => [
        for (final id in layerOrder)
          if (_selection.contains(id)) id,
      ];

  void _shiftLayers({required bool up}) {
    final order = layerOrder;
    final selected = _selectedInPaintOrder().toSet();
    if (selected.isEmpty) return;
    if (up) {
      for (var i = order.length - 2; i >= 0; i--) {
        if (selected.contains(order[i]) && !selected.contains(order[i + 1])) {
          final above = order[i + 1];
          order[i + 1] = order[i];
          order[i] = above;
        }
      }
    } else {
      for (var i = 1; i < order.length; i++) {
        if (selected.contains(order[i]) && !selected.contains(order[i - 1])) {
          final below = order[i - 1];
          order[i - 1] = order[i];
          order[i] = below;
        }
      }
    }
    _setLayers(order, up ? 'Bring forward' : 'Send backward');
  }

  void _setLayers(List<String> paintOrder, String label) {
    final item = currentItem;
    if (item == null) return;
    if (_sameOrder(paintOrder, layerOrder) &&
        item.elementsInPaintOrder.indexed.every((e) => e.$2.zIndex == e.$1)) {
      return;
    }
    execute(ReorderLayersCommand(item.id, paintOrder, label: label));
  }

  static bool _sameOrder(List<String> a, List<String> b) => listEquals(a, b);

  // ---------------------------------------------------------------------------
  // Alignment
  // ---------------------------------------------------------------------------

  /// Aligns the selected, unlocked elements to each other, or to the canvas
  /// when only one is selected.
  void alignSelection(StoryAlignment alignment) {
    final targets = editableSelection;
    if (targets.isEmpty) return;
    final reference = targets.length == 1
        ? _document.canvas.bounds
        : StoryElementGeometry.unionBounds(
            [for (final e in targets) e.transform]);
    if (reference == null) return;
    updateElements([
      for (final e in targets)
        e.copyWithCommon(
          transform: e.transform.translate(_alignDelta(
              StoryElementGeometry.bounds(e.transform), reference, alignment)),
        ),
    ], label: 'Align');
  }

  static StoryPoint _alignDelta(
      StoryRect box, StoryRect reference, StoryAlignment alignment) {
    return switch (alignment) {
      StoryAlignment.left => StoryPoint(reference.left - box.left, 0),
      StoryAlignment.centerHorizontal =>
        StoryPoint(reference.center.x - box.center.x, 0),
      StoryAlignment.right => StoryPoint(reference.right - box.right, 0),
      StoryAlignment.top => StoryPoint(0, reference.top - box.top),
      StoryAlignment.centerVertical =>
        StoryPoint(0, reference.center.y - box.center.y),
      StoryAlignment.bottom => StoryPoint(0, reference.bottom - box.bottom),
    };
  }

  /// Spaces three or more selected, unlocked elements so their centers are
  /// evenly distributed between the outermost two.
  void distributeSelection(StoryDistribution distribution) {
    final targets = [...editableSelection];
    if (targets.length < 3) return;
    final horizontal = distribution == StoryDistribution.horizontal;
    double coordinate(StoryElement e) =>
        horizontal ? e.transform.position.x : e.transform.position.y;
    targets.sort((a, b) => coordinate(a).compareTo(coordinate(b)));
    final first = coordinate(targets.first);
    final step = (coordinate(targets.last) - first) / (targets.length - 1);
    updateElements([
      for (final (i, e) in targets.indexed)
        e.copyWithCommon(
          transform: e.transform.copyWith(
            position: horizontal
                ? StoryPoint(first + step * i, e.transform.position.y)
                : StoryPoint(e.transform.position.x, first + step * i),
          ),
        ),
    ], label: 'Distribute');
  }

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Starts inline editing of the text element [elementId] and selects it.
  void beginTextEditing(String elementId) {
    final element = elementById(elementId);
    if (element is! TextElement || element.locked) return;
    _editingTextId = elementId;
    _selection =
        StoryEditorSelection(itemId: _currentItemId, elementIds: [elementId]);
    _changed();
  }

  /// Ends inline text editing.
  void endTextEditing() {
    if (_editingTextId == null) return;
    _editingTextId = null;
    _changed();
  }

  /// Replaces the text of the text element [elementId].
  void setText(String elementId, String text) {
    final element = elementById(elementId);
    if (element is! TextElement || element.text == text) return;
    updateElement(element.copyWith(text: text), label: 'Edit text');
  }

  // ---------------------------------------------------------------------------
  // Story items (timeline)
  // ---------------------------------------------------------------------------

  /// Items of the current group, in order.
  List<StoryItem> get currentGroupItems => currentGroup?.items ?? const [];

  /// Adds a story item after the current one (or at [index] in [groupId]),
  /// shows it, and returns its id.
  String addItem({StoryItem? item, String? groupId, int? index}) {
    _checkNotDisposed();
    final targetGroup = groupId ??
        currentGroup?.id ??
        _document.groups.firstOrNull?.id ??
        addGroup();
    final group = _document.groupById(targetGroup);
    final currentIndex =
        currentGroupItems.indexWhere((i) => i.id == _currentItemId);
    final position = index ??
        (group != null && group.id == currentGroup?.id && currentIndex >= 0
            ? currentIndex + 1
            : group?.items.length ?? 0);
    final newItem = item ??
        StoryItem(
          id: ids.next('item'),
          duration: FixedItemDuration(config.newItemDuration),
        );
    execute(
      AddItemCommand(targetGroup, newItem, index: position),
      selectAfter: StoryEditorSelection(itemId: newItem.id),
    );
    _currentItemId = newItem.id;
    _selection = StoryEditorSelection(itemId: newItem.id);
    _changed();
    return newItem.id;
  }

  /// Duplicates the item with [itemId] (with fresh element ids) after it and
  /// shows the copy. Returns the new id.
  String duplicateItem(String itemId) {
    final item = _document.itemById(itemId);
    final group = _document.groupOfItem(itemId);
    if (item == null || group == null) {
      throw StoryNotFoundException(itemId, 'No item with id "$itemId"');
    }
    final copy = item.copyWith(
      id: ids.next('item'),
      elements: [for (final e in item.elements) _withId(e, ids.next(e.type))],
    );
    final index = group.items.indexWhere((i) => i.id == itemId) + 1;
    return addItem(item: copy, groupId: group.id, index: index);
  }

  /// Deletes the item with [itemId]; the canvas moves to a neighbor.
  void removeItem(String itemId) {
    final group = _document.groupOfItem(itemId);
    if (group == null) return;
    final index = group.items.indexWhere((i) => i.id == itemId);
    final neighbor = index + 1 < group.items.length
        ? group.items[index + 1].id
        : (index > 0 ? group.items[index - 1].id : null);
    execute(
      RemoveItemCommand(itemId),
      selectAfter: StoryEditorSelection(itemId: neighbor),
    );
    if (_currentItemId == itemId ||
        _document.itemById(_currentItemId ?? '') == null) {
      _currentItemId = neighbor ?? _document.allItems.firstOrNull?.id;
      _selection = StoryEditorSelection(itemId: _currentItemId);
      _changed();
    }
  }

  /// Moves the item with [itemId] to [toIndex] within its group, or into
  /// [toGroupId].
  void moveItem(String itemId, int toIndex, {String? toGroupId}) {
    final group = _document.groupOfItem(itemId);
    if (group == null) return;
    final target = toGroupId ?? group.id;
    final current = group.items.indexWhere((i) => i.id == itemId);
    if (target == group.id && current == toIndex) return;
    execute(MoveItemCommand(itemId, toGroupId: target, toIndex: toIndex));
  }

  /// Sets how long the item with [itemId] is shown (`null`: playback default).
  void setItemDuration(String itemId, StoryItemDuration? duration) {
    final item = _requireItem(itemId);
    if (item.duration == duration) return;
    execute(UpdateItemCommand(_rebuildItem(item, duration: (duration,)),
        label: 'Change duration'));
  }

  /// Sets the entrance transition of the item with [itemId] (`null`: viewer
  /// default).
  void setItemTransition(
      String itemId, StoryTransitionConfiguration? transition) {
    final item = _requireItem(itemId);
    if (item.transition == transition) return;
    execute(UpdateItemCommand(_rebuildItem(item, transition: (transition,)),
        label: 'Change transition'));
  }

  /// Sets the background of the item with [itemId] (`null`: canvas default).
  void setItemBackground(String itemId, StoryBackground? background) {
    final item = _requireItem(itemId);
    if (item.background == background) return;
    execute(UpdateItemCommand(_rebuildItem(item, background: (background,)),
        label: 'Change background'));
  }

  /// Sets the trim range of the video or audio element [elementId] in the
  /// current item. A `null` [end] plays to the end of the media.
  void setMediaTrim(String elementId,
      {required Duration start, Duration? end}) {
    final element = elementById(elementId);
    final StoryElement trimmed;
    switch (element) {
      case VideoElement():
        trimmed = VideoElement(
          id: element.id,
          transform: element.transform,
          source: element.source,
          fit: element.fit,
          poster: element.poster,
          volume: element.volume,
          muted: element.muted,
          loop: element.loop,
          trimStart: start,
          trimEnd: end,
          opacity: element.opacity,
          zIndex: element.zIndex,
          visible: element.visible,
          locked: element.locked,
          semanticLabel: element.semanticLabel,
          metadata: element.metadata,
          customData: element.customData,
        );
      case AudioElement():
        trimmed = AudioElement(
          id: element.id,
          transform: element.transform,
          source: element.source,
          volume: element.volume,
          muted: element.muted,
          loop: element.loop,
          trimStart: start,
          trimEnd: end,
          opacity: element.opacity,
          zIndex: element.zIndex,
          visible: element.visible,
          locked: element.locked,
          semanticLabel: element.semanticLabel,
          metadata: element.metadata,
          customData: element.customData,
        );
      default:
        return;
    }
    if (trimmed == element) return;
    updateElement(trimmed, label: 'Trim');
  }

  StoryItem _requireItem(String itemId) =>
      _document.itemById(itemId) ??
      (throw StoryNotFoundException(itemId, 'No item with id "$itemId"'));

  /// Rebuilds [item]; a record argument means "replace with this value",
  /// including `null`.
  static StoryItem _rebuildItem(
    StoryItem item, {
    (StoryItemDuration?,)? duration,
    (StoryTransitionConfiguration?,)? transition,
    (StoryBackground?,)? background,
  }) {
    return StoryItem(
      id: item.id,
      elements: item.elements,
      background: background == null ? item.background : background.$1,
      duration: duration == null ? item.duration : duration.$1,
      transition: transition == null ? item.transition : transition.$1,
      playback: item.playback,
      metadata: item.metadata,
      customData: item.customData,
    );
  }

  // ---------------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------------

  /// Adds a group with one empty item and returns the group id.
  String addGroup({String? title}) {
    final group = StoryGroup(
      id: ids.next('group'),
      title: title,
      items: [
        StoryItem(
            id: ids.next('item'),
            duration: FixedItemDuration(config.newItemDuration)),
      ],
    );
    execute(AddGroupCommand(group));
    return group.id;
  }

  /// Renames the group with [groupId].
  void renameGroup(String groupId, String title) {
    final group = _document.groupById(groupId);
    if (group == null || group.title == title) return;
    execute(UpdateGroupCommand(group.copyWith(title: title), label: 'Rename'));
  }

  /// Deletes the group with [groupId].
  void removeGroup(String groupId) {
    if (_document.groupById(groupId) == null) return;
    execute(RemoveGroupCommand(groupId));
  }

  // ---------------------------------------------------------------------------
  // Validation and lifecycle
  // ---------------------------------------------------------------------------

  /// Validates the current document.
  StoryValidationResult validate() => validator.validate(_document);

  /// Switches the active tool.
  void setActiveTool(String toolId) {
    if (_activeToolId == toolId) return;
    _activeToolId = toolId;
    _editingTextId = null;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    guides.dispose();
    marquee.dispose();
    brush.dispose();
    super.dispose();
  }

  void _changed({bool documentChanged = false}) {
    if (_disposed) return;
    notifyListeners();
    if (documentChanged) onDocumentChanged?.call(_document);
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw const ControllerDisposedException('StoryEditorController');
    }
  }

  StoryDocument _blankDocument() => StoryDocument(
        id: ids.next('story'),
        groups: [
          StoryGroup(id: ids.next('group'), items: [
            StoryItem(
              id: ids.next('item'),
              duration: FixedItemDuration(config.newItemDuration),
            ),
          ]),
        ],
      );

  /// A copy of [element] with a new [id].
  static StoryElement _withId(StoryElement element, String id) {
    return switch (element) {
      ImageElement() => element.copyWith(id: id),
      VideoElement() => element.copyWith(id: id),
      AudioElement() => element.copyWith(id: id),
      TextElement() => element.copyWith(id: id),
      StickerElement() => element.copyWith(id: id),
      ShapeElement() => element.copyWith(id: id),
      DrawingElement() => element.copyWith(id: id),
      WidgetElement() => element.copyWith(id: id),
      CustomElement() => element.copyWith(id: id),
      InteractiveElement() => element.copyWith(id: id),
      UnknownElement() => UnknownElement(
          id: id,
          transform: element.transform,
          originalType: element.originalType,
          rawJson: element.rawJson,
          opacity: element.opacity,
          zIndex: element.zIndex,
          visible: element.visible,
          locked: element.locked,
          semanticLabel: element.semanticLabel,
          metadata: element.metadata,
          customData: element.customData,
        ),
    };
  }

  /// Applies [transform] to [element], keeping everything else.
  static StoryElement withTransform(
          StoryElement element, StoryTransform transform) =>
      element.copyWithCommon(transform: transform);
}

final class _Transaction {
  _Transaction(this.label, this.document, this.selection, this.currentItemId);

  final String label;
  final StoryDocument document;
  final StoryEditorSelection selection;
  final String? currentItemId;
  int depth = 0;
  bool touched = false;
}
