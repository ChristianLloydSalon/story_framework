import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../composition/elements/interactions.dart';
import '../../../composition/elements/story_element.dart';
import '../../../interactions/story_interaction_controller.dart';
import '../../../interactions/story_interaction_state.dart';
import '../../contracts/story_element_renderer.dart';
import 'interaction_widgets.dart';

/// Formats the time left until a countdown ends, such as `2d 03:14:05`.
String formatStoryCountdown(Duration remaining) {
  if (remaining <= Duration.zero) return 'Ended';
  String two(int value) => value.toString().padLeft(2, '0');
  final days = remaining.inDays;
  final clock = '${two(remaining.inHours % 24)}:'
      '${two(remaining.inMinutes % 60)}:${two(remaining.inSeconds % 60)}';
  return days > 0 ? '${days}d $clock' : clock;
}

/// A countdown with a reminder toggle; ticks every second until it ends.
class StoryCountdownInteractionView extends StatefulWidget {
  /// Creates the view for a countdown [element].
  const StoryCountdownInteractionView({
    required this.element,
    required this.renderContext,
    super.key,
  });

  /// A countdown element.
  final InteractiveElement element;

  /// Where the element is rendered.
  final StoryRenderContext renderContext;

  @override
  State<StoryCountdownInteractionView> createState() =>
      _StoryCountdownInteractionViewState();
}

class _StoryCountdownInteractionViewState
    extends State<StoryCountdownInteractionView> {
  StoryInteractionScope? _scope;
  Timer? _ticker;

  DateTime? get _endsAt {
    final interaction = widget.element.interaction;
    return interaction is StoryCountdown ? interaction.endsAt : null;
  }

  DateTime _now() => (_scope?.now ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = StoryInteractionScope.maybeOf(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(StoryCountdownInteractionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final endsAt = _endsAt;
    final running = endsAt != null && _now().isBefore(endsAt);
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        final end = _endsAt;
        if (end == null || !_now().isBefore(end)) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.element.interaction;
    final title = interaction is StoryCountdown ? interaction.title : '';
    final endsAt = _endsAt;
    final remaining =
        endsAt == null ? Duration.zero : endsAt.difference(_now());
    final ended = remaining <= Duration.zero;
    final scope = _scope;
    final controller = scope?.controller;
    final active = scope != null && scope.enabled ? controller : null;
    final reminderSet = controller
            ?.stateOf<StoryCountdownState>(widget.element.id)
            ?.reminderSet ??
        false;
    final accent = storyAccentOf(widget.element);
    final shown = formatStoryCountdown(remaining);

    return StoryInteractionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center, style: storyInteractionTitle),
          const SizedBox(height: 20),
          Semantics(
            label: ended ? '$title has ended' : 'Ends in $shown',
            excludeSemantics: true,
            child: Text(
              shown,
              style: storyInteractionTitle.copyWith(
                  fontSize: 72, color: accent, letterSpacing: 2),
            ),
          ),
          if (!ended) ...[
            const SizedBox(height: 24),
            StoryInteractionButton(
              semanticLabel: reminderSet ? 'Reminder set' : 'Remind me',
              focusColor: accent,
              onPressed: active == null
                  ? null
                  : () => active.toggleReminder(
                      widget.element, widget.renderContext.item.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Text(
                  reminderSet ? '🔔 Reminder set' : '🔔 Remind me',
                  style: storyInteractionBody.copyWith(color: accent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A link tag. Taps are reported to the app; the framework opens nothing.
class StoryLinkInteractionView extends StatelessWidget {
  /// Creates the view for a link [element].
  const StoryLinkInteractionView({
    required this.element,
    required this.renderContext,
    super.key,
  });

  /// A link element.
  final InteractiveElement element;

  /// Where the element is rendered.
  final StoryRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    final interaction = element.interaction;
    final label = interaction is StoryLink ? interaction.label : '';
    final scope = StoryInteractionScope.maybeOf(context);
    final controller = scope?.controller;
    final active = scope != null && scope.enabled ? controller : null;
    return StoryInteractionButton(
      semanticLabel: 'Link: $label',
      focusColor: storyAccentOf(element),
      borderRadius: 60,
      onPressed: active == null
          ? null
          : () => active.tapLink(element, renderContext.item.id),
      child: StoryInteractionPill(leading: '🔗', label: label),
    );
  }
}

/// A product tag. Taps are reported to the app.
class StoryProductInteractionView extends StatelessWidget {
  /// Creates the view for a product [element].
  const StoryProductInteractionView({
    required this.element,
    required this.renderContext,
    super.key,
  });

  /// A product tag element.
  final InteractiveElement element;

  /// Where the element is rendered.
  final StoryRenderContext renderContext;

  @override
  Widget build(BuildContext context) {
    final interaction = element.interaction;
    final (name, price) = interaction is StoryProductTag
        ? (interaction.name, interaction.priceLabel)
        : ('', null);
    final scope = StoryInteractionScope.maybeOf(context);
    final controller = scope?.controller;
    final active = scope != null && scope.enabled ? controller : null;
    return StoryInteractionButton(
      semanticLabel:
          price == null ? 'Product: $name' : 'Product: $name, $price',
      focusColor: storyAccentOf(element),
      borderRadius: 60,
      onPressed: active == null
          ? null
          : () => active.tapProduct(element, renderContext.item.id),
      child: StoryInteractionPill(leading: '🛍', label: name, trailing: price),
    );
  }
}
