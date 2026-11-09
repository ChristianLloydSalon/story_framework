import 'package:meta/meta.dart';

import '../../core/utilities/json.dart';

/// One choice in a poll or quiz.
@immutable
final class StoryChoice {
  /// Creates a choice.
  const StoryChoice({required this.id, required this.label});

  /// Identifier, unique within the poll or quiz.
  final String id;

  /// Text shown to viewers.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is StoryChoice && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'StoryChoice($id, $label)';
}

/// What an interactive element asks of the viewer.
///
/// These are the authored, serialized part of an interaction. Runtime state
/// (votes, answers, slider values) lives in `StoryInteractionController`, not
/// in the document.
@immutable
sealed class StoryInteraction {
  const StoryInteraction();

  /// Serialization identifier, such as `poll`.
  String get kind;
}

/// A question with two or more choices; viewers vote for one.
final class StoryPoll extends StoryInteraction {
  /// Creates a poll.
  StoryPoll({required this.question, required List<StoryChoice> choices})
      : choices = List.unmodifiable(choices);

  /// Serialization identifier.
  static const String kindId = 'poll';

  /// The question.
  final String question;

  /// The choices, in display order.
  final List<StoryChoice> choices;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StoryPoll &&
      other.question == question &&
      deepEquals(other.choices, choices);

  @override
  int get hashCode => Object.hash(question, deepHash(choices));
}

/// A question with one correct choice.
final class StoryQuiz extends StoryInteraction {
  /// Creates a quiz; [correctChoiceId] must match one of [choices].
  StoryQuiz({
    required this.question,
    required List<StoryChoice> choices,
    required this.correctChoiceId,
  }) : choices = List.unmodifiable(choices);

  /// Serialization identifier.
  static const String kindId = 'quiz';

  /// The question.
  final String question;

  /// The choices, in display order.
  final List<StoryChoice> choices;

  /// The id of the correct choice.
  final String correctChoiceId;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StoryQuiz &&
      other.question == question &&
      other.correctChoiceId == correctChoiceId &&
      deepEquals(other.choices, choices);

  @override
  int get hashCode => Object.hash(question, correctChoiceId, deepHash(choices));
}

/// An open question; viewers type a reply.
final class StoryQuestion extends StoryInteraction {
  /// Creates a question.
  const StoryQuestion({
    required this.prompt,
    this.placeholder = 'Type something…',
  });

  /// Serialization identifier.
  static const String kindId = 'question';

  /// The prompt.
  final String prompt;

  /// Hint shown in the empty reply field.
  final String placeholder;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StoryQuestion &&
      other.prompt == prompt &&
      other.placeholder == placeholder;

  @override
  int get hashCode => Object.hash(prompt, placeholder);
}

/// A rating slider from 0 to 1, usually with an emoji handle.
final class StorySlider extends StoryInteraction {
  /// Creates a slider.
  const StorySlider({required this.question, this.emoji = '😍'});

  /// Serialization identifier.
  static const String kindId = 'slider';

  /// The question.
  final String question;

  /// The handle emoji.
  final String emoji;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StorySlider &&
      other.question == question &&
      other.emoji == emoji;

  @override
  int get hashCode => Object.hash(question, emoji);
}

/// A countdown to [endsAt]; viewers can ask to be reminded.
final class StoryCountdown extends StoryInteraction {
  /// Creates a countdown.
  const StoryCountdown({required this.title, required this.endsAt});

  /// Serialization identifier.
  static const String kindId = 'countdown';

  /// What is being counted down to.
  final String title;

  /// When the countdown ends.
  final DateTime endsAt;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StoryCountdown && other.title == title && other.endsAt == endsAt;

  @override
  int get hashCode => Object.hash(title, endsAt);
}

/// A tappable link.
///
/// The framework never opens URLs itself; taps are reported to the app,
/// which decides whether and how to open them.
final class StoryLink extends StoryInteraction {
  /// Creates a link.
  const StoryLink({required this.url, required this.label});

  /// Serialization identifier.
  static const String kindId = 'link';

  /// The destination.
  final Uri url;

  /// Text shown on the link.
  final String label;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StoryLink && other.url == url && other.label == label;

  @override
  int get hashCode => Object.hash(url, label);
}

/// A tag pointing at a product in the app's catalog.
final class StoryProductTag extends StoryInteraction {
  /// Creates a product tag.
  const StoryProductTag({
    required this.productId,
    required this.name,
    this.priceLabel,
  });

  /// Serialization identifier.
  static const String kindId = 'product';

  /// The app's product identifier.
  final String productId;

  /// Product name shown on the tag.
  final String name;

  /// Pre-formatted price, such as `$24.99`, if shown.
  final String? priceLabel;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StoryProductTag &&
      other.productId == productId &&
      other.name == name &&
      other.priceLabel == priceLabel;

  @override
  int get hashCode => Object.hash(productId, name, priceLabel);
}

/// An application-defined interaction, rendered by an app builder registered
/// for [type].
final class StoryCustomInteraction extends StoryInteraction {
  /// Creates a custom interaction.
  StoryCustomInteraction(this.type, {JsonMap data = const {}})
      : data = freezeJsonMap(data, name: 'data');

  /// Serialization identifier.
  static const String kindId = 'custom';

  /// The app's interaction type.
  final String type;

  /// JSON-compatible interaction data.
  final JsonMap data;

  @override
  String get kind => kindId;

  @override
  bool operator ==(Object other) =>
      other is StoryCustomInteraction &&
      other.type == type &&
      deepEquals(other.data, data);

  @override
  int get hashCode => Object.hash(type, deepHash(data));
}
