import 'package:flutter/widgets.dart';

import '../composition/elements/interactions.dart';
import '../composition/elements/story_element.dart';
import '../core/contracts/story_playback_hold.dart';
import '../core/utilities/json.dart';
import 'story_interaction_state.dart';

/// Receives every interaction.
typedef StoryInteractionCallback = void Function(StoryInteractionEvent event);

/// Holds interaction state for a document and reports what viewers do.
///
/// Interaction widgets call the action methods; the controller updates the
/// state, notifies listeners, and forwards a [StoryInteractionEvent] to
/// [onInteraction]. Apps seed and refresh state with [setState], for example
/// with aggregated poll results from their backend.
class StoryInteractionController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [initialStates] is keyed by element id. When [allowChangingAnswers] is
  /// `false`, votes, quiz answers, and slider ratings are final.
  StoryInteractionController({
    Map<String, StoryInteractionState> initialStates = const {},
    this.onInteraction,
    this.allowChangingAnswers = false,
  }) : _states = Map.of(initialStates);

  /// Receives every interaction.
  final StoryInteractionCallback? onInteraction;

  /// Whether viewers may change a vote, quiz answer, or rating.
  final bool allowChangingAnswers;

  final Map<String, StoryInteractionState> _states;

  /// The state of [elementId] if it is a [T], else `null`.
  T? stateOf<T extends StoryInteractionState>(String elementId) {
    final state = _states[elementId];
    return state is T ? state : null;
  }

  /// Replaces the state of [elementId].
  void setState(String elementId, StoryInteractionState state) {
    if (_states[elementId] == state) return;
    _states[elementId] = state;
    notifyListeners();
  }

  /// Forgets the state of [elementId].
  void clearState(String elementId) {
    if (_states.remove(elementId) != null) notifyListeners();
  }

  /// Records a poll vote or quiz answer. Returns `false` if the viewer has
  /// already answered and changing answers is not allowed, or if [choiceId]
  /// is not a choice of [element].
  bool selectChoice(
    InteractiveElement element,
    String itemId,
    String choiceId,
  ) {
    final (choices, correctId) = switch (element.interaction) {
      StoryPoll(:final choices) => (choices, null),
      StoryQuiz(:final choices, :final correctChoiceId) => (
          choices,
          correctChoiceId
        ),
      _ => (const <StoryChoice>[], null),
    };
    if (!choices.any((choice) => choice.id == choiceId)) return false;

    final current = stateOf<StoryChoiceState>(element.id);
    final previous = current?.selectedChoiceId;
    if (previous == choiceId) return false;
    if (previous != null && !allowChangingAnswers) return false;

    final counts = Map.of(current?.counts ?? const <String, int>{});
    if (counts.isNotEmpty) {
      if (previous != null) {
        counts[previous] = ((counts[previous] ?? 1) - 1).clamp(0, 1 << 31);
      }
      counts[choiceId] = (counts[choiceId] ?? 0) + 1;
    }
    setState(
      element.id,
      StoryChoiceState(selectedChoiceId: choiceId, counts: counts),
    );
    onInteraction?.call(StoryChoiceSelectedEvent(
      element: element,
      itemId: itemId,
      choiceId: choiceId,
      isCorrect: correctId == null ? null : correctId == choiceId,
    ));
    return true;
  }

  /// Records a slider rating, clamped to 0–1. Returns `false` if the viewer
  /// has already rated and changing answers is not allowed.
  bool submitSlider(InteractiveElement element, String itemId, double value) {
    final current = stateOf<StorySliderState>(element.id);
    if (current != null && current.hasAnswered && !allowChangingAnswers) {
      return false;
    }
    final rating = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    setState(
      element.id,
      StorySliderState(value: rating, average: current?.average),
    );
    onInteraction?.call(StorySliderSubmittedEvent(
        element: element, itemId: itemId, value: rating));
    return true;
  }

  /// Sends a reply to a question. Returns `false` for blank text.
  bool replyToQuestion(InteractiveElement element, String itemId, String text) {
    final reply = text.trim();
    if (reply.isEmpty) return false;
    final current = stateOf<StoryQuestionState>(element.id);
    setState(
      element.id,
      StoryQuestionState(replies: (current?.replies ?? 0) + 1),
    );
    onInteraction?.call(StoryQuestionRepliedEvent(
        element: element, itemId: itemId, text: reply));
    return true;
  }

  /// Turns a countdown reminder on or off and returns the new setting.
  bool toggleReminder(InteractiveElement element, String itemId) {
    final current = stateOf<StoryCountdownState>(element.id);
    final next = !(current?.reminderSet ?? false);
    setState(element.id, StoryCountdownState(reminderSet: next));
    onInteraction?.call(StoryCountdownReminderEvent(
        element: element, itemId: itemId, reminderSet: next));
    return next;
  }

  /// Reports a link tap.
  void tapLink(InteractiveElement element, String itemId) {
    final interaction = element.interaction;
    if (interaction is! StoryLink) return;
    onInteraction?.call(StoryLinkTappedEvent(
        element: element, itemId: itemId, url: interaction.url));
  }

  /// Reports a product tag tap.
  void tapProduct(InteractiveElement element, String itemId) {
    final interaction = element.interaction;
    if (interaction is! StoryProductTag) return;
    onInteraction?.call(StoryProductTappedEvent(
        element: element, itemId: itemId, productId: interaction.productId));
  }

  /// Reports an app-defined [action] from a custom interaction.
  void reportCustom(
    InteractiveElement element,
    String itemId,
    String action, {
    JsonMap data = const {},
  }) {
    onInteraction?.call(StoryCustomInteractionEvent(
      element: element,
      itemId: itemId,
      action: action,
      data: data,
    ));
  }
}

/// Makes a [StoryInteractionController] available to interaction widgets.
///
/// The viewer installs one. Without a scope, or with [enabled] `false`
/// (for example in an editor preview), interactive elements render as
/// static, inert previews.
class StoryInteractionScope
    extends InheritedNotifier<StoryInteractionController> {
  /// Creates a scope.
  const StoryInteractionScope({
    required StoryInteractionController controller,
    required super.child,
    this.holdPlayback,
    this.enabled = true,
    this.now = DateTime.now,
    super.key,
  }) : super(notifier: controller);

  /// Pauses playback while the viewer interacts (dragging, typing).
  final StoryPlaybackHoldFactory? holdPlayback;

  /// Whether interactions are accepted.
  final bool enabled;

  /// The current time, for countdowns. Injectable for tests.
  final DateTime Function() now;

  /// The controller.
  StoryInteractionController? get controller => notifier;

  /// The nearest scope, or `null`. Rebuilds the caller on state changes.
  static StoryInteractionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoryInteractionScope>();

  @override
  bool updateShouldNotify(StoryInteractionScope oldWidget) =>
      oldWidget.enabled != enabled ||
      oldWidget.holdPlayback != holdPlayback ||
      oldWidget.now != now ||
      super.updateShouldNotify(oldWidget);
}
