/// The headless playback engine: [StoryController], its configuration,
/// timing abstractions, events, and lifecycle integration.
///
/// The engine has no dependency on the viewer and can drive playback without
/// any UI.
library;

import 'src/engine/controller/story_controller.dart';

export 'media.dart';
export 'src/configuration/playback/story_playback_config.dart';
export 'src/engine/controller/story_controller.dart';
export 'src/engine/lifecycle/story_app_lifecycle_binding.dart';
export 'src/engine/playback/playback_events.dart';
export 'src/engine/state/story_selection.dart';
export 'src/engine/timeline/story_clock.dart';
export 'src/engine/widgets/story_playback_selector.dart';
