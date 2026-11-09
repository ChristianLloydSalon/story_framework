import 'dart:async';

import 'package:meta/meta.dart';

import '../../composition/document/story_document.dart';
import '../../composition/items/item_timing.dart';
import '../../composition/items/story_item.dart';
import '../../core/errors/story_exceptions.dart';

/// Something that happened during playback.
///
/// Events complement the state snapshot for things that are moments rather
/// than states, such as marking an item as seen.
@immutable
sealed class StoryPlaybackEvent {
  const StoryPlaybackEvent();
}

/// An item became the current item and started preparing.
final class StoryItemStartedEvent extends StoryPlaybackEvent {
  /// Creates the event for the item at [location].
  const StoryItemStartedEvent(this.location);

  /// The item that started.
  final StoryItemLocation location;

  @override
  bool operator ==(Object other) =>
      other is StoryItemStartedEvent && other.location == location;

  @override
  int get hashCode => Object.hash(StoryItemStartedEvent, location);

  @override
  String toString() => 'StoryItemStartedEvent($location)';
}

/// An item played to its end.
///
/// Not emitted when the user skips an item before it ends.
final class StoryItemCompletedEvent extends StoryPlaybackEvent {
  /// Creates the event for the item at [location].
  const StoryItemCompletedEvent(this.location);

  /// The item that completed.
  final StoryItemLocation location;

  @override
  bool operator ==(Object other) =>
      other is StoryItemCompletedEvent && other.location == location;

  @override
  int get hashCode => Object.hash(StoryItemCompletedEvent, location);

  @override
  String toString() => 'StoryItemCompletedEvent($location)';
}

/// The last item of a group played to its end.
final class StoryGroupCompletedEvent extends StoryPlaybackEvent {
  /// Creates the event for the group at [groupIndex].
  const StoryGroupCompletedEvent(this.groupIndex);

  /// Index of the completed group.
  final int groupIndex;

  @override
  bool operator ==(Object other) =>
      other is StoryGroupCompletedEvent && other.groupIndex == groupIndex;

  @override
  int get hashCode => Object.hash(StoryGroupCompletedEvent, groupIndex);

  @override
  String toString() => 'StoryGroupCompletedEvent($groupIndex)';
}

/// Playback reached the end of the document (or of a group when
/// `continueToNextGroup` is off).
final class StoryPlaybackCompletedEvent extends StoryPlaybackEvent {
  /// Creates the event.
  const StoryPlaybackCompletedEvent();

  @override
  bool operator ==(Object other) => other is StoryPlaybackCompletedEvent;

  @override
  int get hashCode => (StoryPlaybackCompletedEvent).hashCode;

  @override
  String toString() => 'StoryPlaybackCompletedEvent()';
}

/// An item failed to load or play.
final class StoryPlaybackErrorEvent extends StoryPlaybackEvent {
  /// Creates the event for [error] at [location].
  const StoryPlaybackErrorEvent(this.error, this.location);

  /// The failure.
  final StoryException error;

  /// The item that failed, if any.
  final StoryItemLocation? location;

  @override
  bool operator ==(Object other) =>
      other is StoryPlaybackErrorEvent &&
      other.error == error &&
      other.location == location;

  @override
  int get hashCode => Object.hash(error, location);

  @override
  String toString() => 'StoryPlaybackErrorEvent($location, $error)';
}

/// Resolves a [CustomItemDuration] at runtime.
///
/// Register providers on `StoryController` by
/// [CustomItemDuration.providerId].
abstract interface class StoryDurationProvider {
  /// Returns the duration of [item], or `null` for an indefinite item that
  /// never advances by itself.
  FutureOr<Duration?> resolve(StoryItem item, CustomItemDuration duration);
}
