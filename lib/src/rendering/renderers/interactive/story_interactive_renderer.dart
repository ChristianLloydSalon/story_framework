import 'package:flutter/widgets.dart';

import '../../../composition/elements/interactions.dart';
import '../../../composition/elements/story_element.dart';
import '../../../core/errors/story_exceptions.dart';
import '../../contracts/story_element_renderer.dart';
import 'choice_view.dart';
import 'countdown_and_tag_views.dart';
import 'question_view.dart';
import 'slider_view.dart';

/// Builds a [StoryCustomInteraction].
typedef StoryCustomInteractionBuilder = Widget Function(
  BuildContext context,
  InteractiveElement element,
  StoryCustomInteraction interaction,
  StoryRenderContext renderContext,
);

/// Renders [InteractiveElement]s with the built-in interaction views, or
/// with [customBuilders] for custom interaction types.
///
/// Views read `StoryInteractionScope` for state and actions. Without a scope
/// (for example in an editor or export), they render as inert previews.
final class StoryInteractiveRenderer
    extends StoryElementRenderer<InteractiveElement> {
  /// Creates the renderer.
  const StoryInteractiveRenderer({this.customBuilders = const {}});

  /// Builders keyed by [StoryCustomInteraction.type].
  final Map<String, StoryCustomInteractionBuilder> customBuilders;

  @override
  String get id => InteractiveElement.typeId;

  @override
  bool supports(StoryElement element) =>
      element is InteractiveElement &&
      switch (element.interaction) {
        StoryCustomInteraction(:final type) => customBuilders.containsKey(type),
        _ => true,
      };

  @override
  Widget buildElement(
    BuildContext context,
    InteractiveElement element,
    StoryRenderContext renderContext,
  ) {
    return switch (element.interaction) {
      StoryPoll() || StoryQuiz() => StoryChoiceInteractionView(
          element: element, renderContext: renderContext),
      StoryQuestion() => StoryQuestionInteractionView(
          element: element, renderContext: renderContext),
      StorySlider() => StorySliderInteractionView(
          element: element, renderContext: renderContext),
      StoryCountdown() => StoryCountdownInteractionView(
          element: element, renderContext: renderContext),
      StoryLink() => StoryLinkInteractionView(
          element: element, renderContext: renderContext),
      StoryProductTag() => StoryProductInteractionView(
          element: element, renderContext: renderContext),
      final StoryCustomInteraction custom => switch (
            customBuilders[custom.type]) {
          final builder? => builder(context, element, custom, renderContext),
          null => StoryElementError(
              renderContext: renderContext,
              error: RendererNotRegisteredException(element.type,
                  'No builder for custom interaction "${custom.type}"'),
            ),
        },
    };
  }
}
