import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../composition/elements/story_element.dart';
import '../../conversions.dart';

/// Default accent for interactive elements without an `accentColor`.
const Color storyDefaultAccent = Color(0xFF7C4DFF);

/// Dark text on interaction cards.
const Color storyInteractionInk = Color(0xFF1F1F24);

/// The accent color of [element].
Color storyAccentOf(InteractiveElement element) =>
    element.accentColor?.toColor() ?? storyDefaultAccent;

/// Text sizes are in canvas units (a 1080-wide canvas by default).
const TextStyle storyInteractionTitle = TextStyle(
  color: storyInteractionInk,
  fontSize: 46,
  fontWeight: FontWeight.w700,
  height: 1.2,
);

/// Body text on interaction cards.
const TextStyle storyInteractionBody = TextStyle(
  color: storyInteractionInk,
  fontSize: 40,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

/// Lays [child] out at the available width and scales it down if it is
/// taller than the element box, so content never overflows.
class StoryFitWidth extends StatelessWidget {
  /// Creates the fitter.
  const StoryFitWidth({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : 800,
          child: child,
        ),
      ),
    );
  }
}

/// The white rounded card interaction stickers sit on.
class StoryInteractionCard extends StatelessWidget {
  /// Creates a card.
  const StoryInteractionCard({required this.child, super.key});

  /// The card content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StoryFitWidth(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
                color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 8)),
          ],
        ),
        child: Padding(padding: const EdgeInsets.all(36), child: child),
      ),
    );
  }
}

/// A focusable, keyboard- and screen-reader-operable button.
///
/// Enter and space activate it when focused. With a `null` [onPressed] it is
/// shown but inert (used for previews).
class StoryInteractionButton extends StatefulWidget {
  /// Creates a button.
  const StoryInteractionButton({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.focusColor = storyDefaultAccent,
    this.borderRadius = 28,
    super.key,
  });

  /// Spoken by screen readers.
  final String semanticLabel;

  /// Called on activation, or `null` when inert.
  final VoidCallback? onPressed;

  /// The visible content.
  final Widget child;

  /// Outline color while keyboard-focused.
  final Color focusColor;

  /// Corner radius of the focus outline.
  final double borderRadius;

  @override
  State<StoryInteractionButton> createState() => _StoryInteractionButtonState();
}

class _StoryInteractionButtonState extends State<StoryInteractionButton> {
  bool _focused = false;
  bool _hasFocus = false;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  void _activate() => widget.onPressed?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      focusable: enabled,
      focused: _hasFocus,
      label: widget.semanticLabel,
      onTap: enabled ? _activate : null,
      child: FocusableActionDetector(
        onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
        enabled: enabled,
        shortcuts: _shortcuts,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _activate : null,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: _focused
                  ? Border.all(color: widget.focusColor, width: 6)
                  : null,
            ),
            child: ExcludeSemantics(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// A rounded pill used by link and product tags.
class StoryInteractionPill extends StatelessWidget {
  /// Creates a pill.
  const StoryInteractionPill({
    required this.leading,
    required this.label,
    this.trailing,
    super.key,
  });

  /// Icon-like text before the label, such as an emoji.
  final String leading;

  /// Main text.
  final String label;

  /// Secondary text after the label, such as a price.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final extra = trailing;
    return StoryFitWidth(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(60),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 24),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(leading, style: storyInteractionBody),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    label,
                    style: storyInteractionBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (extra != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    extra,
                    style: storyInteractionBody.copyWith(
                        color: const Color(0xFF6B6B78)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
