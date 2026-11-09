import 'package:meta/meta.dart';

import '../../core/utilities/json.dart';

/// How long a story item stays on screen.
@immutable
sealed class StoryItemDuration {
  const StoryItemDuration();
}

/// A fixed display time, typical for images and text.
final class FixedItemDuration extends StoryItemDuration {
  /// Shows the item for [duration].
  const FixedItemDuration(this.duration);

  /// Display time.
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is FixedItemDuration && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'FixedItemDuration($duration)';
}

/// Lasts as long as a media element (video or audio) in the item.
final class MediaItemDuration extends StoryItemDuration {
  /// Follows the media element [elementId], or the first time-based element
  /// when [elementId] is `null`.
  ///
  /// [maxDuration] caps long media. [fallback] is used when the media length
  /// cannot be determined.
  const MediaItemDuration({this.elementId, this.maxDuration, this.fallback});

  /// The element whose media length drives the item, if specified.
  final String? elementId;

  /// Upper bound on the item duration.
  final Duration? maxDuration;

  /// Duration used when the media length is unknown.
  final Duration? fallback;

  @override
  bool operator ==(Object other) =>
      other is MediaItemDuration &&
      other.elementId == elementId &&
      other.maxDuration == maxDuration &&
      other.fallback == fallback;

  @override
  int get hashCode => Object.hash(elementId, maxDuration, fallback);

  @override
  String toString() => 'MediaItemDuration(${elementId ?? 'first media'})';
}

/// Never advances automatically, for interactive content.
final class IndefiniteItemDuration extends StoryItemDuration {
  /// Creates an indefinite duration.
  const IndefiniteItemDuration();

  @override
  bool operator ==(Object other) => other is IndefiniteItemDuration;

  @override
  int get hashCode => (IndefiniteItemDuration).hashCode;

  @override
  String toString() => 'IndefiniteItemDuration()';
}

/// Resolved at runtime by an application-registered duration provider.
final class CustomItemDuration extends StoryItemDuration {
  /// Uses the provider registered as [providerId], passing it [data].
  CustomItemDuration(this.providerId, {JsonMap data = const {}})
      : data = freezeJsonMap(data, name: 'data');

  /// The registered duration provider.
  final String providerId;

  /// Provider-specific JSON-compatible data.
  final JsonMap data;

  @override
  bool operator ==(Object other) =>
      other is CustomItemDuration &&
      other.providerId == providerId &&
      deepEquals(other.data, data);

  @override
  int get hashCode => Object.hash(providerId, deepHash(data));

  @override
  String toString() => 'CustomItemDuration($providerId)';
}

/// How an item animates in when it becomes current.
///
/// [type] names a transition registered with the transition system (for
/// example `fade` or `slide`). The transition [duration] is independent of the
/// item's display duration.
@immutable
final class StoryTransitionConfiguration {
  /// Creates a transition configuration.
  StoryTransitionConfiguration({
    required this.type,
    this.duration = const Duration(milliseconds: 300),
    this.curve = 'easeInOut',
    JsonMap parameters = const {},
  }) : parameters = freezeJsonMap(parameters, name: 'parameters');

  /// Registered transition identifier.
  final String type;

  /// Animation length.
  final Duration duration;

  /// Name of the easing curve, such as `linear` or `easeInOut`.
  final String curve;

  /// Transition-specific JSON-compatible parameters.
  final JsonMap parameters;

  /// Returns a copy with the given fields replaced.
  StoryTransitionConfiguration copyWith({
    String? type,
    Duration? duration,
    String? curve,
    JsonMap? parameters,
  }) {
    return StoryTransitionConfiguration(
      type: type ?? this.type,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      parameters: parameters ?? this.parameters,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StoryTransitionConfiguration &&
      other.type == type &&
      other.duration == duration &&
      other.curve == curve &&
      deepEquals(other.parameters, parameters);

  @override
  int get hashCode => Object.hash(type, duration, curve, deepHash(parameters));

  @override
  String toString() => 'StoryTransitionConfiguration($type, $duration)';
}

/// Per-item overrides of the global playback configuration.
///
/// `null` fields inherit the value from the playback configuration.
@immutable
final class StoryItemPlaybackConfiguration {
  /// Creates per-item playback overrides.
  const StoryItemPlaybackConfiguration({this.autoAdvance});

  /// No overrides.
  static const StoryItemPlaybackConfiguration inherit =
      StoryItemPlaybackConfiguration();

  /// Whether playback moves to the next item when this one ends.
  final bool? autoAdvance;

  /// Whether every field inherits.
  bool get isInherited => autoAdvance == null;

  @override
  bool operator ==(Object other) =>
      other is StoryItemPlaybackConfiguration &&
      other.autoAdvance == autoAdvance;

  @override
  int get hashCode => autoAdvance.hashCode;
}
