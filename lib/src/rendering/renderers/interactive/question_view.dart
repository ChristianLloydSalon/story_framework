import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../composition/elements/interactions.dart';
import '../../../composition/elements/story_element.dart';
import '../../../core/contracts/story_playback_hold.dart';
import '../../../interactions/story_interaction_controller.dart';
import '../../../interactions/story_interaction_state.dart';
import '../../contracts/story_element_renderer.dart';
import 'interaction_widgets.dart';

/// An open question with an inline reply field.
///
/// Playback is held while the reply field has focus, so the story does not
/// advance while the viewer is typing.
class StoryQuestionInteractionView extends StatefulWidget {
  /// Creates the view for a question [element].
  const StoryQuestionInteractionView({
    required this.element,
    required this.renderContext,
    super.key,
  });

  /// A question element.
  final InteractiveElement element;

  /// Where the element is rendered.
  final StoryRenderContext renderContext;

  @override
  State<StoryQuestionInteractionView> createState() =>
      _StoryQuestionInteractionViewState();
}

class _StoryQuestionInteractionViewState
    extends State<StoryQuestionInteractionView> {
  final TextEditingController _reply = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'story question reply');
  StoryInteractionScope? _scope;
  StoryPlaybackHold? _hold;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = StoryInteractionScope.maybeOf(context);
  }

  @override
  void dispose() {
    _hold?.release();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _reply.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      _hold ??= _scope?.holdPlayback?.call();
    } else {
      _hold?.release();
      _hold = null;
    }
  }

  void _send() {
    final controller = _scope?.controller;
    if (controller == null) return;
    final sent = controller.replyToQuestion(
        widget.element, widget.renderContext.item.id, _reply.text);
    if (sent) {
      _reply.clear();
      _focus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.element.interaction;
    final (prompt, placeholder) = interaction is StoryQuestion
        ? (interaction.prompt, interaction.placeholder)
        : ('', '');
    final scope = _scope;
    final controller = scope?.controller;
    final enabled = scope != null && scope.enabled && controller != null;
    final replies =
        controller?.stateOf<StoryQuestionState>(widget.element.id)?.replies ??
            0;
    final accent = storyAccentOf(widget.element);

    return StoryInteractionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(prompt,
              textAlign: TextAlign.center, style: storyInteractionTitle),
          const SizedBox(height: 28),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F0F5),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                children: [
                  Expanded(
                    child: enabled
                        ? _ReplyField(
                            reply: _reply,
                            focus: _focus,
                            placeholder: placeholder,
                            accent: accent,
                            onSubmitted: _send,
                          )
                        : Text(
                            placeholder,
                            style: storyInteractionBody.copyWith(
                                color: const Color(0xFF8E8E99)),
                          ),
                  ),
                  const SizedBox(width: 16),
                  StoryInteractionButton(
                    semanticLabel: 'Send reply',
                    onPressed: enabled ? _send : null,
                    focusColor: accent,
                    child: Text('Send',
                        style: storyInteractionBody.copyWith(color: accent)),
                  ),
                ],
              ),
            ),
          ),
          if (replies > 0)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  replies == 1 ? 'Reply sent' : '$replies replies sent',
                  textAlign: TextAlign.center,
                  style: storyInteractionBody.copyWith(
                      color: const Color(0xFF6B6B78)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyField extends StatelessWidget {
  const _ReplyField({
    required this.reply,
    required this.focus,
    required this.placeholder,
    required this.accent,
    required this.onSubmitted,
  });

  final TextEditingController reply;
  final FocusNode focus;
  final String placeholder;
  final Color accent;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: placeholder,
      child: Stack(
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: reply,
            builder: (context, value, child) => value.text.isEmpty
                ? Text(
                    placeholder,
                    style: storyInteractionBody.copyWith(
                        color: const Color(0xFF8E8E99)),
                  )
                : const SizedBox.shrink(),
          ),
          EditableText(
            controller: reply,
            focusNode: focus,
            style: storyInteractionBody,
            cursorColor: accent,
            backgroundCursorColor: const Color(0xFF8E8E99),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmitted(),
          ),
        ],
      ),
    );
  }
}
