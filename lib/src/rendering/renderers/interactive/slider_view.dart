import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../composition/elements/interactions.dart';
import '../../../composition/elements/story_element.dart';
import '../../../core/contracts/story_playback_hold.dart';
import '../../../interactions/story_interaction_controller.dart';
import '../../../interactions/story_interaction_state.dart';
import '../../contracts/story_element_renderer.dart';
import 'interaction_widgets.dart';

/// A rating slider with an emoji handle.
///
/// Dragging holds playback and submits on release. Keyboard users move the
/// handle with the arrow keys and submit with Enter; screen readers adjust
/// it with increase and decrease actions.
class StorySliderInteractionView extends StatefulWidget {
  /// Creates the view for a slider [element].
  const StorySliderInteractionView({
    required this.element,
    required this.renderContext,
    super.key,
  });

  /// A slider element.
  final InteractiveElement element;

  /// Where the element is rendered.
  final StoryRenderContext renderContext;

  @override
  State<StorySliderInteractionView> createState() =>
      _StorySliderInteractionViewState();
}

class _StorySliderInteractionViewState
    extends State<StorySliderInteractionView> {
  static const double _step = 0.1;

  StoryInteractionScope? _scope;
  StoryPlaybackHold? _hold;

  /// The handle position while dragging or adjusting with keys.
  double? _pending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = StoryInteractionScope.maybeOf(context);
  }

  @override
  void dispose() {
    _hold?.release();
    super.dispose();
  }

  StoryInteractionController? get _controller => _scope?.controller;

  StorySliderState? get _state =>
      _controller?.stateOf<StorySliderState>(widget.element.id);

  bool get _canRate {
    final scope = _scope;
    final controller = _controller;
    if (scope == null || !scope.enabled || controller == null) return false;
    return !(_state?.hasAnswered ?? false) || controller.allowChangingAnswers;
  }

  double get _shown => _pending ?? _state?.value ?? 0.5;

  void _submit(double value) {
    _controller?.submitSlider(
        widget.element, widget.renderContext.item.id, value);
    setState(() => _pending = null);
  }

  void _dragTo(double localX, double width) {
    if (width <= 0) return;
    setState(() => _pending = (localX / width).clamp(0.0, 1.0));
  }

  void _startDrag() {
    _hold ??= _scope?.holdPlayback?.call();
  }

  void _endDrag() {
    _hold?.release();
    _hold = null;
    final value = _pending;
    if (value != null) _submit(value);
  }

  void _nudge(double delta) {
    if (!_canRate) return;
    setState(() => _pending = (_shown + delta).clamp(0.0, 1.0));
  }

  void _commitPending() {
    final value = _pending;
    if (value != null && _canRate) _submit(value);
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.element.interaction;
    final (question, emoji) = interaction is StorySlider
        ? (interaction.question, interaction.emoji)
        : ('', '😍');
    final accent = storyAccentOf(widget.element);
    final canRate = _canRate;
    final value = _shown;
    final average = (_state?.hasAnswered ?? false) ? _state?.average : null;
    final percent = (value * 100).round();

    final track = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const handle = 96.0;
        final averageValue = average;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: canRate
              ? (details) {
                  _startDrag();
                  _dragTo(details.localPosition.dx, width);
                }
              : null,
          onHorizontalDragUpdate: canRate
              ? (details) => _dragTo(details.localPosition.dx, width)
              : null,
          onHorizontalDragEnd: canRate ? (_) => _endDrag() : null,
          onHorizontalDragCancel: canRate ? _endDrag : null,
          onTapUp: canRate
              ? (details) {
                  _dragTo(details.localPosition.dx, width);
                  _commitPending();
                }
              : null,
          child: SizedBox(
            height: handle,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.centerStart,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [accent.withAlpha(0x55), accent],
                        ),
                      ),
                    ),
                  ),
                ),
                if (averageValue != null)
                  Positioned(
                    left: (width * averageValue - 4).clamp(0.0, width),
                    top: 18,
                    bottom: 18,
                    child: const SizedBox(
                      width: 8,
                      child: ColoredBox(color: storyInteractionInk),
                    ),
                  ),
                Positioned(
                  left: (width * value - handle / 2)
                      .clamp(-handle / 2, width - handle / 2),
                  child: SizedBox.square(
                    dimension: handle,
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 80, height: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return StoryInteractionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question,
              textAlign: TextAlign.center, style: storyInteractionTitle),
          const SizedBox(height: 36),
          Semantics(
            slider: true,
            enabled: canRate,
            label: question,
            value: '$percent percent',
            increasedValue:
                '${(((value + _step).clamp(0.0, 1.0)) * 100).round()} percent',
            decreasedValue:
                '${(((value - _step).clamp(0.0, 1.0)) * 100).round()} percent',
            onIncrease:
                canRate ? () => _submit((value + _step).clamp(0.0, 1.0)) : null,
            onDecrease:
                canRate ? () => _submit((value - _step).clamp(0.0, 1.0)) : null,
            excludeSemantics: true,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _nudge(_step),
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _nudge(-_step),
                const SingleActivator(LogicalKeyboardKey.enter): _commitPending,
              },
              child: Focus(canRequestFocus: canRate, child: track),
            ),
          ),
          if (average != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Average ${(average * 100).round()}%',
                textAlign: TextAlign.center,
                style: storyInteractionBody.copyWith(
                    color: const Color(0xFF6B6B78)),
              ),
            ),
        ],
      ),
    );
  }
}
