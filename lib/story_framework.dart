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
/// * `package:story_framework/viewer.dart` — the story viewer, gestures, and
///   overlays.
/// * `package:story_framework/animations.dart` — story transitions.
/// * `package:story_framework/editor.dart` — the story editor.
///
/// The export entry point is added when that module is implemented.
library;

export 'animations.dart';
export 'composition.dart';
export 'editor.dart';
export 'engine.dart';
export 'media.dart';
export 'rendering.dart';
export 'viewer.dart';
