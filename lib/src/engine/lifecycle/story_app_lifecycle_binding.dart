import 'package:flutter/widgets.dart';

import '../../core/enums/story_enums.dart';
import '../controller/story_controller.dart';

/// Holds a [StoryController] with [StoryPauseReason.appBackground] while the
/// application is not in the foreground.
///
/// The default viewer installs one automatically. Headless users create it
/// next to their controller and dispose it first:
///
/// ```dart
/// final binding = StoryAppLifecycleBinding(controller);
/// // ...
/// binding.dispose();
/// await controller.dispose();
/// ```
///
/// Requires an initialized [WidgetsBinding].
final class StoryAppLifecycleBinding {
  /// Starts observing the application lifecycle for [controller].
  ///
  /// Playback is held in every state listed in [pauseIn].
  StoryAppLifecycleBinding(
    this.controller, {
    this.pauseIn = const {
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    },
  }) {
    _listener = AppLifecycleListener(onStateChange: _apply);
    final current = WidgetsBinding.instance.lifecycleState;
    if (current != null) _apply(current);
  }

  /// The controller being held and released.
  final StoryController controller;

  /// Lifecycle states that hold playback.
  final Set<AppLifecycleState> pauseIn;

  late final AppLifecycleListener _listener;

  void _apply(AppLifecycleState state) {
    if (controller.isDisposed) return;
    if (pauseIn.contains(state)) {
      controller.addPauseReason(StoryPauseReason.appBackground);
    } else {
      controller.removePauseReason(StoryPauseReason.appBackground);
    }
  }

  /// Stops observing and clears the pause reason it added.
  void dispose() {
    _listener.dispose();
    if (!controller.isDisposed) {
      controller.removePauseReason(StoryPauseReason.appBackground);
    }
  }
}
