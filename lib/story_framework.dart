/// Story Framework: create, compose, edit, render, and play multimedia stories.
///
/// Importing this library exposes every stable public API. Focused entry
/// points are also available:
///
/// * `package:story_framework/composition.dart` — documents, elements,
///   serialization, and validation (no Flutter widgets).
/// * `package:story_framework/media.dart` — media provider contracts.
/// * `package:story_framework/engine.dart` — headless playback.
/// * `package:story_framework/rendering.dart` — renderers and item views.
///
/// Viewer, editor, animation, and export entry points are added as those
/// modules are implemented.
library;

export 'composition.dart';
export 'engine.dart';
export 'media.dart';
export 'rendering.dart';
