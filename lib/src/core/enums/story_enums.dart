/// How visual content is inscribed into its box.
///
/// Mirrors Flutter's `BoxFit` without depending on it.
enum StoryFit {
  /// Fill the box, distorting the aspect ratio.
  fill,

  /// As large as possible while fully contained.
  contain,

  /// As small as possible while covering the whole box.
  cover,

  /// Match the box width.
  fitWidth,

  /// Match the box height.
  fitHeight,

  /// Keep the intrinsic size.
  none,

  /// Like [contain], but never scale up.
  scaleDown,
}

/// Horizontal alignment of text within its box.
enum StoryTextAlign {
  /// Align to the left edge.
  left,

  /// Align to the right edge.
  right,

  /// Center the text.
  center,

  /// Stretch lines to fill the width.
  justify,

  /// Align to the leading edge for the text direction.
  start,

  /// Align to the trailing edge for the text direction.
  end,
}

/// How a canvas is scaled to fit the available viewport.
enum StoryScalingBehavior {
  /// Show the whole canvas, letterboxing if needed.
  contain,

  /// Fill the viewport, cropping the canvas if needed.
  cover,

  /// Stretch the canvas to the viewport, distorting the aspect ratio.
  fill,
}

/// Lifecycle status of a playback session.
enum StoryPlaybackStatus {
  /// Nothing has started yet.
  idle,

  /// The current item is preparing its content.
  loading,

  /// The timeline is advancing.
  playing,

  /// The timeline is held by one or more pause reasons.
  paused,

  /// Every item in the document has finished.
  completed,

  /// Playback stopped because of an error.
  error,
}

/// Whether the current item is waiting for media data.
enum StoryBufferingStatus {
  /// Enough data is available.
  ready,

  /// Waiting for data before the timeline can advance.
  buffering,
}

/// Independent reasons that can hold playback.
///
/// Playback resumes only when every active reason has been cleared.
enum StoryPauseReason {
  /// The user paused explicitly (for example, a long press).
  user,

  /// The host application moved to the background.
  appBackground,

  /// Media is buffering.
  buffering,

  /// A modal route or dialog is presented above the story.
  modal,

  /// A navigation overlay (for example, a swipe-to-dismiss drag) is active.
  navigationOverlay,

  /// Any other interruption reported by the host application.
  external,

  /// The viewer is interacting with story content, such as dragging a
  /// slider or typing a reply.
  interaction,
}

/// Status of an individual media resource.
enum StoryMediaStatus {
  /// Created but not initialized.
  uninitialized,

  /// Initialization in progress.
  initializing,

  /// Initialized and ready to play.
  ready,

  /// Waiting for more data.
  buffering,

  /// Playing.
  playing,

  /// Paused.
  paused,

  /// Reached the end of the media.
  completed,

  /// Failed; see the accompanying error.
  error,

  /// Disposed; it can no longer be used.
  disposed,
}
