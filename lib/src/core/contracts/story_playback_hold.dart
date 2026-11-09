/// A claim that keeps playback paused until released.
///
/// Holds are reference counted per pause reason: playback stays held for a
/// reason while any hold for it is active, so independent widgets (a slider
/// being dragged, an overlay being pressed) never release each other's pause.
abstract interface class StoryPlaybackHold {
  /// Whether this hold is still in effect.
  bool get isActive;

  /// Ends this hold. Calling it again has no effect.
  void release();
}

/// Creates a playback hold, for code that must not depend on the engine.
typedef StoryPlaybackHoldFactory = StoryPlaybackHold Function();
