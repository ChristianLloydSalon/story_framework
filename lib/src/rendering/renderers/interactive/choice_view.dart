import 'package:flutter/widgets.dart';

import '../../../composition/elements/interactions.dart';
import '../../../composition/elements/story_element.dart';
import '../../../interactions/story_interaction_controller.dart';
import '../../../interactions/story_interaction_state.dart';
import '../../contracts/story_element_renderer.dart';
import 'interaction_widgets.dart';

const Color _correct = Color(0xFF2EB872);
const Color _incorrect = Color(0xFFE5484D);

/// A poll or quiz: a question and its choices.
///
/// Before answering, choices are buttons. After answering, each choice shows
/// its share of votes when results are known; quizzes mark the correct
/// choice and a wrong pick.
class StoryChoiceInteractionView extends StatelessWidget {
  /// Creates the view for a poll or quiz [element].
  const StoryChoiceInteractionView({
    required this.element,
    required this.renderContext,
    super.key,
  });

  /// A poll or quiz element.
  final InteractiveElement element;

  /// Where the element is rendered.
  final StoryRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    final (question, choices, correctId) = switch (element.interaction) {
      StoryPoll(:final question, :final choices) => (question, choices, null),
      StoryQuiz(:final question, :final choices, :final correctChoiceId) => (
          question,
          choices,
          correctChoiceId
        ),
      _ => ('', const <StoryChoice>[], null),
    };
    final scope = StoryInteractionScope.maybeOf(context);
    final controller = scope?.controller;
    final active = scope != null && scope.enabled ? controller : null;
    final state = controller?.stateOf<StoryChoiceState>(element.id);
    final answered = state?.hasAnswered ?? false;
    final answerWith =
        active != null && (!answered || active.allowChangingAnswers)
            ? active
            : null;
    final accent = storyAccentOf(element);
    final itemId = renderContext.item.id;

    return StoryInteractionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question,
              textAlign: TextAlign.center, style: storyInteractionTitle),
          const SizedBox(height: 28),
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ChoiceRow(
                choice: choice,
                accent: accent,
                answered: answered,
                selected: state?.selectedChoiceId == choice.id,
                share: answered ? state?.shareOf(choice.id) : null,
                correct: correctId == null || !answered
                    ? null
                    : correctId == choice.id,
                isQuiz: correctId != null,
                onPressed: answerWith == null
                    ? null
                    : () => answerWith.selectChoice(element, itemId, choice.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.choice,
    required this.accent,
    required this.answered,
    required this.selected,
    required this.share,
    required this.correct,
    required this.isQuiz,
    required this.onPressed,
  });

  final StoryChoice choice;
  final Color accent;
  final bool answered;
  final bool selected;
  final double? share;
  final bool? correct;
  final bool isQuiz;
  final VoidCallback? onPressed;

  String get _semanticLabel {
    if (!answered) {
      return isQuiz ? 'Answer ${choice.label}' : 'Vote ${choice.label}';
    }
    final parts = <String>[choice.label];
    final fraction = share;
    if (fraction != null) parts.add('${(fraction * 100).round()} percent');
    if (correct == true) parts.add('correct answer');
    if (selected) {
      parts.add(isQuiz && correct == false
          ? 'your answer, incorrect'
          : 'your choice');
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final fraction = share;
    final highlight = switch (correct) {
      true => _correct,
      false when selected => _incorrect,
      _ => accent,
    };
    final fill = answered ? (fraction ?? (selected ? 1.0 : 0.0)) : 0.0;
    return StoryInteractionButton(
      semanticLabel: _semanticLabel,
      onPressed: onPressed,
      focusColor: accent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F0F5),
            border: Border.all(
              color: selected ? highlight : const Color(0x00000000),
              width: 4,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fill.clamp(0.0, 1.0),
                  child: ColoredBox(color: highlight.withAlpha(0x55)),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(choice.label, style: storyInteractionBody),
                    ),
                    if (answered && fraction != null)
                      Text('${(fraction * 100).round()}%',
                          style: storyInteractionBody),
                    if (answered && correct == true)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 12),
                        child: Text('✓',
                            style: TextStyle(color: _correct, fontSize: 40)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
