/// The story editor: [StoryEditorController], editing commands with undo and
/// redo, tools, the editing canvas, and the default [StoryEditor] UI.
///
/// The editor shares the composition model and rendering system with the
/// viewer and does not depend on playback.
library;

import 'src/editor/controller/story_editor_controller.dart';
import 'src/editor/widgets/story_editor.dart';

export 'animations.dart';
export 'rendering.dart';
export 'src/composition/editing/document_edits.dart';
export 'src/configuration/editor/story_editor_config.dart';
export 'src/editor/canvas/story_editor_canvas.dart';
export 'src/editor/canvas/story_editor_viewport.dart';
export 'src/editor/controller/story_editor_controller.dart';
export 'src/editor/controller/story_id_generator.dart';
export 'src/editor/geometry/element_geometry.dart';
export 'src/editor/geometry/story_snapping.dart';
export 'src/editor/geometry/transform_math.dart';
export 'src/editor/history/story_edit_command.dart';
export 'src/editor/history/story_edit_history.dart';
export 'src/editor/selection/story_editor_selection.dart';
export 'src/editor/tools/builtin_tools.dart';
export 'src/editor/tools/story_editor_tool.dart';
export 'src/editor/widgets/editor_controls.dart';
export 'src/editor/widgets/story_editor.dart';
