import 'package:meta/meta.dart';

import '../composition/elements/story_element.dart';
import '../core/utilities/json.dart';

/// Runtime state of one interactive element, such as a viewer's vote.
///
/// State is not part of the document. Apps seed it (for example with the
/// viewer's earlier vote and aggregated results from their backend) and
/// update it as results arrive.
@immutable
sealed class StoryInteractionState {
  const StoryInteractionState();
}

/// The viewer's choice in a poll or quiz, plus optional results.
final class StoryChoiceState extends StoryInteractionState {
  /// Creates choice state.
  ///
  /// [counts] holds votes per choice id, if the app knows them; an empty map
  /// means results are unknown and only the viewer's own choice is shown.
  StoryChoiceState({this.selectedChoiceId, Map<String, int> counts = const {}})
      : counts = Map.unmodifiable(counts);

  /// The choice the viewer picked, or `null` before answering.
  final String? selectedChoiceId;

  /// Votes per choice id; empty when unknown.
  final Map<String, int> counts;

  /// Whether the viewer has answered.
  bool get hasAnswered => selectedChoiceId != null;

  /// Total votes in [counts].
  int get totalVotes => counts.values.fold(0, (sum, count) => sum + count);

  /// Share of votes for [choiceId] between 0 and 1, or `null` when results
  /// are unknown.
  double? shareOf(String choiceId) {
    final total = totalVotes;
    if (total <= 0) return null;
    return (counts[choiceId] ?? 0) / total;
  }

  @override
  bool operator ==(Object other) =>
      other is StoryChoiceState &&
      other.selectedChoiceId == selectedChoiceId &&
      deepEquals(other.counts, counts);

  @override
  int get hashCode => Object.hash(selectedChoiceId, deepHash(counts));
}

/// The viewer's slider rating, plus the optional average of all ratings.
final class StorySliderState extends StoryInteractionState {
  /// Creates slider state.
  const StorySliderState({this.value, this.average});

  /// The viewer's rating between 0 and 1, or `null` before rating.
  final double? value;

  /// Average of all ratings between 0 and 1, if known.
  final double? average;

  /// Whether the viewer has rated.
  bool get hasAnswered => value != null;

  @override
  bool operator ==(Object other) =>
      other is StorySliderState &&
      other.value == value &&
      other.average == average;

  @override
  int get hashCode => Object.hash(value, average);
}

/// How many replies the viewer has sent to a question.
///
/// Reply texts are not kept: they go to the app through the interaction
/// callback.
final class StoryQuestionState extends StoryInteractionState {
  /// Creates question state.
  const StoryQuestionState({this.replies = 0});

  /// Replies sent so far.
  final int replies;

  @override
  bool operator ==(Object other) =>
      other is StoryQuestionState && other.replies == replies;

  @override
  int get hashCode => replies.hashCode;
}

/// Whether the viewer asked to be reminded when a countdown ends.
final class StoryCountdownState extends StoryInteractionState {
  /// Creates countdown state.
  const StoryCountdownState({this.reminderSet = false});

  /// Whether a reminder is set.
  final bool reminderSet;

  @override
  bool operator ==(Object other) =>
      other is StoryCountdownState && other.reminderSet == reminderSet;

  @override
  int get hashCode => reminderSet.hashCode;
}

/// Something a viewer did with an interactive element.
///
/// Delivered to the app through `StoryInteractionController.onInteraction`;
/// the app persists votes, sends replies, opens links, and so on.
@immutable
sealed class StoryInteractionEvent {
  const StoryInteractionEvent({required this.element, required this.itemId});

  /// The element interacted with.
  final InteractiveElement element;

  /// The item that contains [element].
  final String itemId;
}

/// A poll vote or quiz answer.
final class StoryChoiceSelectedEvent extends StoryInteractionEvent {
  /// Creates the event.
  const StoryChoiceSelectedEvent({
    required super.element,
    required super.itemId,
    required this.choiceId,
    this.isCorrect,
  });

  /// The picked choice.
  final String choiceId;

  /// For quizzes, whether the answer is correct; `null` for polls.
  final bool? isCorrect;
}

/// A slider rating.
final class StorySliderSubmittedEvent extends StoryInteractionEvent {
  /// Creates the event.
  const StorySliderSubmittedEvent({
    required super.element,
    required super.itemId,
    required this.value,
  });

  /// The rating between 0 and 1.
  final double value;
}

/// A reply to a question.
final class StoryQuestionRepliedEvent extends StoryInteractionEvent {
  /// Creates the event.
  const StoryQuestionRepliedEvent({
    required super.element,
    required super.itemId,
    required this.text,
  });

  /// The reply, trimmed and non-empty.
  final String text;
}

/// A countdown reminder was set or cleared.
final class StoryCountdownReminderEvent extends StoryInteractionEvent {
  /// Creates the event.
  const StoryCountdownReminderEvent({
    required super.element,
    required super.itemId,
    required this.reminderSet,
  });

  /// Whether the reminder is now set.
  final bool reminderSet;
}

/// A link was tapped. The app decides whether to open it.
final class StoryLinkTappedEvent extends StoryInteractionEvent {
  /// Creates the event.
  const StoryLinkTappedEvent({
    required super.element,
    required super.itemId,
    required this.url,
  });

  /// The link destination.
  final Uri url;
}

/// A product tag was tapped.
final class StoryProductTappedEvent extends StoryInteractionEvent {
  /// Creates the event.
  const StoryProductTappedEvent({
    required super.element,
    required super.itemId,
    required this.productId,
  });

  /// The app's product id.
  final String productId;
}

/// An app-defined action from a custom interaction.
final class StoryCustomInteractionEvent extends StoryInteractionEvent {
  /// Creates the event.
  StoryCustomInteractionEvent({
    required super.element,
    required super.itemId,
    required this.action,
    JsonMap data = const {},
  }) : data = freezeJsonMap(data, name: 'data');

  /// What happened, as named by the app.
  final String action;

  /// Action details.
  final JsonMap data;
}
