import 'package:meta/meta.dart';

import '../../composition/document/story_document.dart';
import '../selection/story_editor_selection.dart';

/// One undoable step: the document and selection before and after it.
@immutable
final class StoryHistoryEntry {
  /// Creates an entry.
  const StoryHistoryEntry({
    required this.label,
    required this.before,
    required this.after,
    required this.selectionBefore,
    required this.selectionAfter,
  });

  /// User-facing name, such as "Move".
  final String label;

  /// The document before the step.
  final StoryDocument before;

  /// The document after the step.
  final StoryDocument after;

  /// The selection before the step.
  final StoryEditorSelection selectionBefore;

  /// The selection after the step.
  final StoryEditorSelection selectionAfter;
}

/// Bounded undo and redo stacks.
///
/// Entries reference whole documents, but documents share every unchanged
/// group, item, and element, so each entry costs roughly the size of the path
/// that changed. [limit] bounds memory for long sessions.
final class StoryEditHistory {
  /// Creates a history keeping at most [limit] undo steps.
  StoryEditHistory({this.limit = 100})
      : assert(limit > 0, 'limit must be positive');

  /// Maximum number of undo steps kept.
  final int limit;

  final List<StoryHistoryEntry> _undo = [];
  final List<StoryHistoryEntry> _redo = [];

  /// Whether there is a step to undo.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether there is a step to redo.
  bool get canRedo => _redo.isNotEmpty;

  /// Label of the step [undo] would revert, or `null`.
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;

  /// Label of the step [redo] would reapply, or `null`.
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  /// Number of undo steps.
  int get undoCount => _undo.length;

  /// Number of redo steps.
  int get redoCount => _redo.length;

  /// Records a new step and clears the redo stack. The oldest step is
  /// dropped when [limit] is exceeded.
  void push(StoryHistoryEntry entry) {
    _undo.add(entry);
    _redo.clear();
    if (_undo.length > limit) _undo.removeAt(0);
  }

  /// Removes and returns the latest step, moving it to the redo stack.
  StoryHistoryEntry? undo() {
    if (_undo.isEmpty) return null;
    final entry = _undo.removeLast();
    _redo.add(entry);
    return entry;
  }

  /// Removes and returns the latest undone step, moving it back.
  StoryHistoryEntry? redo() {
    if (_redo.isEmpty) return null;
    final entry = _redo.removeLast();
    _undo.add(entry);
    return entry;
  }

  /// Forgets every step.
  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
