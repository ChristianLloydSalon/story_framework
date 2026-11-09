import 'package:flutter/foundation.dart';

import '../../core/errors/story_exceptions.dart';
import '../../core/models/geometry.dart';
import '../canvas/story_editor_viewport.dart';
import '../controller/story_editor_controller.dart';

/// Everything a tool needs to act on a canvas gesture.
@immutable
final class StoryToolContext {
  /// Creates a tool context.
  const StoryToolContext({
    required this.controller,
    required this.mapping,
    this.additive = false,
  });

  /// The editor to change.
  final StoryEditorController controller;

  /// Converts between screen and canvas coordinates.
  final StoryViewportMapping mapping;

  /// Whether the user is holding the add-to-selection modifier (Shift).
  final bool additive;

  /// A screen distance in canvas units, for zoom-independent thresholds.
  double canvasDistance(double screenPixels) =>
      mapping.toCanvasDistance(screenPixels);
}

/// A canvas editing mode: selecting, adding text, drawing, and so on.
///
/// The canvas forwards gestures in canvas coordinates to the active tool.
/// Tools are owned by one [StoryEditorToolRegistry] and may keep state
/// between the start and end of a drag. Register custom tools to add new
/// editing behavior without changing the editor.
abstract class StoryEditorTool {
  /// Constructor for subclasses.
  StoryEditorTool();

  /// Unique id within a registry.
  String get id;

  /// Accessible name, such as "Text".
  String get label;

  /// Short glyph shown on the toolbar button, such as "T".
  String get symbol;

  /// Whether selection outlines and transform handles are shown while this
  /// tool is active.
  bool get showsSelection => true;

  /// A tap at [point].
  void onTap(StoryToolContext context, StoryPoint point) {}

  /// A double tap at [point].
  void onDoubleTap(StoryToolContext context, StoryPoint point) {}

  /// A one-finger drag started at [point].
  void onDragStart(StoryToolContext context, StoryPoint point) {}

  /// The drag moved to [point].
  void onDragUpdate(StoryToolContext context, StoryPoint point) {}

  /// The drag ended at [point].
  void onDragEnd(StoryToolContext context, StoryPoint point) {}

  /// The drag was interrupted; undo any in-progress change.
  void onDragCancel(StoryToolContext context) {}
}

/// The tools available in one editor.
class StoryEditorToolRegistry extends ChangeNotifier {
  /// Creates a registry containing exactly [tools].
  StoryEditorToolRegistry([Iterable<StoryEditorTool> tools = const []]) {
    tools.forEach(register);
  }

  final List<StoryEditorTool> _tools = [];

  /// Tools in registration (toolbar) order.
  List<StoryEditorTool> get tools => List.unmodifiable(_tools);

  /// The tool with [id], or `null`.
  StoryEditorTool? lookup(String id) {
    for (final tool in _tools) {
      if (tool.id == id) return tool;
    }
    return null;
  }

  /// Adds [tool]; throws a [ConfigurationException] if its id is taken.
  void register(StoryEditorTool tool) {
    if (lookup(tool.id) != null) {
      throw ConfigurationException(
          'A tool with id "${tool.id}" is already registered; use replace()');
    }
    _tools.add(tool);
    notifyListeners();
  }

  /// Replaces the tool with [tool]'s id, keeping its position.
  void replace(StoryEditorTool tool) {
    final index = _tools.indexWhere((t) => t.id == tool.id);
    if (index < 0) {
      throw ConfigurationException('No tool with id "${tool.id}" to replace');
    }
    _tools[index] = tool;
    notifyListeners();
  }

  /// Removes and returns the tool with [id], or `null`.
  StoryEditorTool? unregister(String id) {
    final index = _tools.indexWhere((t) => t.id == id);
    if (index < 0) return null;
    final removed = _tools.removeAt(index);
    notifyListeners();
    return removed;
  }
}
