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
  }) : _listener = AppLifecycleListener(
          onStateChange: (state) => _apply(controller, pauseIn, state),
        ) {
    final current = WidgetsBinding.instance.lifecycleState;
    if (current != null) _apply(controller, pauseIn, current);
  }

  /// The controller being held and released.
  final StoryController controller;

  /// Lifecycle states that hold playback.
  final Set<AppLifecycleState> pauseIn;

  final AppLifecycleListener _listener;

  static void _apply(
    StoryController controller,
    Set<AppLifecycleState> pauseIn,
    AppLifecycleState state,
  ) {
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
