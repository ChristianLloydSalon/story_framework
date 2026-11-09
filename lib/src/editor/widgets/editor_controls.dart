import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../composition/document/story_document.dart';
import '../../composition/elements/element_styles.dart';
import '../../composition/elements/story_element.dart';
import '../../composition/items/item_timing.dart';
import '../../core/enums/story_enums.dart';
import '../../core/models/story_color.dart';
import '../../rendering/contracts/story_element_renderer.dart';
import '../../rendering/registry/story_renderer_registry.dart';
import '../../rendering/widgets/story_item_view.dart';
import '../controller/story_editor_controller.dart';
import '../tools/builtin_tools.dart';
import '../tools/story_editor_tool.dart';
import 'editor_icons.dart';

/// Colors of the default editor UI.
abstract final class StoryEditorColors {
  /// Workspace background behind the panels.
  static const Color background = Color(0xFF0C0C11);

  /// Panel background.
  static const Color panel = Color(0xFF16161D);

  /// Raised controls inside panels.
  static const Color button = Color(0xFF23232D);

  /// Hovered controls.
  static const Color hover = Color(0xFF2C2C38);

  /// Hairline borders and dividers.
  static const Color border = Color(0xFF2A2A35);

  /// Primary text.
  static const Color text = Color(0xFFF4F4F8);

  /// Secondary text.
  static const Color muted = Color(0xFF8D8D9D);

  /// Selection, focus, and active tools.
  static const Color accent = Color(0xFF7C5CFF);

  /// The second color of the accent gradient.
  static const Color accentSecondary = Color(0xFF4C8DFF);

  /// The accent gradient used for active controls.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentSecondary],
  );
}

/// Swatches offered for text and brush colors.
const List<StoryColor> storyEditorSwatches = [
  StoryColor(0xFFFFFFFF),
  StoryColor(0xFF000000),
  StoryColor(0xFFFF4F5E),
  StoryColor(0xFFFF9F43),
  StoryColor(0xFFFFC23D),
  StoryColor(0xFF3DDC84),
  StoryColor(0xFF4C8DFF),
  StoryColor(0xFFB36BFF),
];

/// A user-facing name for [element]: its `metadata['name']`, its text, or
/// its type.
String storyElementName(StoryElement element) {
  final name = element.metadata['name'];
  if (name is String && name.isNotEmpty) return name;
  return switch (element) {
    TextElement(:final text) => text.trim().isEmpty
        ? 'Text'
        : '“${text.trim().replaceAll(RegExp(r'\s+'), ' ')}”',
    StickerElement(sticker: EmojiSticker(:final emoji)) => 'Sticker $emoji',
    InteractiveElement(:final interaction) =>
      '${interaction.kind[0].toUpperCase()}${interaction.kind.substring(1)}',
    _ => '${element.type[0].toUpperCase()}${element.type.substring(1)}',
  };
}

/// The icon that represents [element]'s type.
StoryEditorIcons storyElementIcon(StoryElement element) => switch (element) {
      TextElement() => StoryEditorIcons.text,
      ImageElement() => StoryEditorIcons.image,
      VideoElement() => StoryEditorIcons.video,
      AudioElement() => StoryEditorIcons.audio,
      StickerElement() => StoryEditorIcons.sticker,
      ShapeElement() => StoryEditorIcons.shape,
      DrawingElement() => StoryEditorIcons.draw,
      InteractiveElement() => StoryEditorIcons.interactive,
      _ => StoryEditorIcons.widget,
    };

/// A rounded card that holds a part of the editor.
class StoryEditorPanel extends StatelessWidget {
  /// Creates a panel.
  const StoryEditorPanel({
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(8),
    super.key,
  });

  /// The content.
  final Widget child;

  /// An optional heading.
  final String? title;

  /// An icon before the heading.
  final StoryEditorIcons? icon;

  /// Widgets at the end of the heading row.
  final Widget? trailing;

  /// Space around [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final icon = this.icon;
    final trailing = this.trailing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StoryEditorColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StoryEditorColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      StoryEditorIcon(icon,
                          size: 16, color: StoryEditorColors.muted),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: StoryEditorColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
              ),
            Expanded(child: Padding(padding: padding, child: child)),
          ],
        ),
      ),
    );
  }
}

/// A compact, focusable, screen-reader-labeled editor button.
///
/// Shows [child], else [icon] (with [glyph] beside it when both are given),
/// else [glyph]. Enter and Space activate it when focused.
class StoryEditorButton extends StatefulWidget {
  /// Creates a button.
  const StoryEditorButton({
    required this.label,
    required this.onPressed,
    this.glyph,
    this.icon,
    this.child,
    this.selected,
    this.tonal = false,
    this.expand = false,
    super.key,
  }) : assert(glyph != null || icon != null || child != null,
            'give the button something to show');

  /// Spoken by screen readers.
  final String label;

  /// Short visible text, such as "Front" or "5s".
  final String? glyph;

  /// A vector icon.
  final StoryEditorIcons? icon;

  /// Custom content; replaces [icon] and [glyph].
  final Widget? child;

  /// Called when activated; `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether the toggle is on (for example the current tool), or `null` for
  /// a plain button that has no on/off state.
  final bool? selected;

  /// Gives the button a raised background even when idle.
  final bool tonal;

  /// Stretches the content to the available width.
  final bool expand;

  @override
  State<StoryEditorButton> createState() => _StoryEditorButtonState();
}

class _StoryEditorButtonState extends State<StoryEditorButton> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  void _activate() => widget.onPressed?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final selected = widget.selected ?? false;
    final foreground = !enabled
        ? StoryEditorColors.muted.withAlpha(0x70)
        : selected
            ? const Color(0xFFFFFFFF)
            : StoryEditorColors.text;
    final background = selected
        ? null
        : _hovered && enabled
            ? StoryEditorColors.hover
            : widget.tonal
                ? StoryEditorColors.button
                : const Color(0x00000000);

    final icon = widget.icon;
    final glyph = widget.glyph;
    final content = widget.child ??
        Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              StoryEditorIcon(icon, size: 18, color: foreground),
            if (icon != null && glyph != null) const SizedBox(width: 6),
            if (glyph != null)
              Flexible(
                child: Text(
                  glyph,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      focusable: enabled,
      focused: _focused,
      label: widget.label,
      onTap: enabled ? _activate : null,
      child: FocusableActionDetector(
        enabled: enabled,
        shortcuts: _shortcuts,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _activate();
            return null;
          }),
        },
        onFocusChange: (focused) => setState(() => _focused = focused),
        onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _activate : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: ExcludeSemantics(
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1,
              duration: const Duration(milliseconds: 90),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                margin: const EdgeInsets.all(2),
                padding: EdgeInsets.symmetric(
                    horizontal: glyph != null || widget.child != null ? 10 : 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  gradient: selected ? StoryEditorColors.accentGradient : null,
                  borderRadius: BorderRadius.circular(10),
                  border: _focused
                      ? Border.all(color: StoryEditorColors.text, width: 1.5)
                      : null,
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x667C5CFF),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small heading for a group of controls.
class StoryEditorSectionLabel extends StatelessWidget {
  /// Creates a label.
  const StoryEditorSectionLabel(this.text, {super.key});

  /// The heading.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
        child: Semantics(
          header: true,
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: StoryEditorColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
}

/// A row of related buttons on a shared raised background.
class StoryEditorButtonGroup extends StatelessWidget {
  /// Creates a group.
  const StoryEditorButtonGroup({required this.children, super.key});

  /// The buttons.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: StoryEditorColors.button,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}

/// A labeled value with minus and plus buttons.
class StoryEditorStepper extends StatelessWidget {
  /// Creates a stepper.
  const StoryEditorStepper({
    required this.title,
    required this.value,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onDecrease,
    required this.onIncrease,
    this.valueLabel,
    this.icon,
    super.key,
  });

  /// What the value is, such as "Size".
  final String title;

  /// The displayed value, such as "72".
  final String value;

  /// Screen-reader text for the value; defaults to "[title] [value]".
  final String? valueLabel;

  /// An icon before [title].
  final StoryEditorIcons? icon;

  /// Screen-reader label of the minus button.
  final String decreaseLabel;

  /// Screen-reader label of the plus button.
  final String increaseLabel;

  /// Called by the minus button; `null` disables it.
  final VoidCallback? onDecrease;

  /// Called by the plus button; `null` disables it.
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            StoryEditorIcon(icon, size: 16, color: StoryEditorColors.muted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ExcludeSemantics(
              child: Text(title,
                  style: const TextStyle(color: StoryEditorColors.muted)),
            ),
          ),
          StoryEditorButtonGroup(children: [
            StoryEditorButton(
              label: decreaseLabel,
              icon: StoryEditorIcons.minus,
              onPressed: onDecrease,
            ),
            Semantics(
              label: valueLabel ?? '$title $value',
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 56,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: StoryEditorColors.text,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            StoryEditorButton(
              label: increaseLabel,
              icon: StoryEditorIcons.plus,
              onPressed: onIncrease,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: StoryEditorColors.border,
      );
}

/// Tool buttons plus undo, redo, duplicate, and delete.
class StoryEditorToolbar extends StatelessWidget {
  /// Creates a toolbar.
  const StoryEditorToolbar({
    required this.controller,
    required this.tools,
    super.key,
  });

  /// The editor.
  final StoryEditorController controller;

  /// The tools to show.
  final StoryEditorToolRegistry tools;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, tools]),
      builder: (context, _) {
        final hasSelection = controller.editableSelection.isNotEmpty;
        final undo = controller.undoLabel;
        final redo = controller.redoLabel;
        final active = tools.lookup(controller.activeToolId);
        final toolButtons = StoryEditorButtonGroup(children: [
          for (final tool in tools.tools)
            StoryEditorButton(
              label: '${tool.label} tool',
              icon: tool.icon,
              glyph: tool.icon == null ? tool.symbol : null,
              selected: controller.activeToolId == tool.id,
              onPressed: () => controller.setActiveTool(tool.id),
            ),
        ]);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: StoryEditorColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StoryEditorColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tools scroll on narrow screens; history stays visible.
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          toolButtons,
                          if (active != null && constraints.maxWidth >= 640)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: ExcludeSemantics(
                                child: Text(
                                  active.label,
                                  style: const TextStyle(
                                    color: StoryEditorColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const _Divider(),
                  StoryEditorButton(
                    label: undo == null ? 'Undo' : 'Undo $undo',
                    icon: StoryEditorIcons.undo,
                    onPressed: controller.canUndo ? controller.undo : null,
                  ),
                  StoryEditorButton(
                    label: redo == null ? 'Redo' : 'Redo $redo',
                    icon: StoryEditorIcons.redo,
                    onPressed: controller.canRedo ? controller.redo : null,
                  ),
                  StoryEditorButton(
                    label: 'Duplicate selection',
                    icon: StoryEditorIcons.duplicate,
                    onPressed:
                        hasSelection ? controller.duplicateSelection : null,
                  ),
                  StoryEditorButton(
                    label: 'Delete selection',
                    icon: StoryEditorIcons.delete,
                    onPressed: hasSelection ? controller.deleteSelection : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The elements of the current item, top layer first, with visibility,
/// lock, and order controls. Also a non-gesture way to select elements.
class StoryLayersPanel extends StatelessWidget {
  /// Creates a layers panel.
  const StoryLayersPanel({required this.controller, super.key});

  /// The editor.
  final StoryEditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final item = controller.currentItem;
        final layers = item?.elementsInPaintOrder.reversed.toList() ?? const [];
        return StoryEditorPanel(
          title: 'Layers',
          icon: StoryEditorIcons.layers,
          trailing: ExcludeSemantics(
            child: Text('${layers.length}',
                style: const TextStyle(color: StoryEditorColors.muted)),
          ),
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: layers.isEmpty
              ? const Center(
                  child: Text('No layers yet',
                      style: TextStyle(color: StoryEditorColors.muted)),
                )
              : ListView(
                  children: [
                    for (final (index, element) in layers.indexed)
                      _LayerRow(
                        controller: controller,
                        element: element,
                        paintIndex: layers.length - 1 - index,
                        count: layers.length,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.controller,
    required this.element,
    required this.paintIndex,
    required this.count,
  });

  final StoryEditorController controller;
  final StoryElement element;
  final int paintIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selection.contains(element.id);
    final name = storyElementName(element);
    final faded = !element.visible;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: selected ? StoryEditorColors.accent.withAlpha(0x2E) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? StoryEditorColors.accent.withAlpha(0x99)
              : const Color(0x00000000),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: StoryEditorButton(
              label: 'Select layer $name',
              onPressed: () => controller.select([element.id]),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: StoryEditorColors.button,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: StoryEditorIcon(storyElementIcon(element),
                        size: 15,
                        color: selected
                            ? StoryEditorColors.text
                            : StoryEditorColors.muted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: faded
                            ? StoryEditorColors.muted
                            : StoryEditorColors.text,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          StoryEditorButton(
            label: element.visible ? 'Hide $name' : 'Show $name',
            icon: element.visible
                ? StoryEditorIcons.visible
                : StoryEditorIcons.hidden,
            onPressed: () => controller.toggleVisible(element.id),
          ),
          StoryEditorButton(
            label: element.locked ? 'Unlock $name' : 'Lock $name',
            icon: element.locked
                ? StoryEditorIcons.lock
                : StoryEditorIcons.unlock,
            selected: element.locked ? true : null,
            onPressed: () => controller.toggleLocked(element.id),
          ),
          StoryEditorButton(
            label: 'Move $name up',
            icon: StoryEditorIcons.chevronUp,
            onPressed: paintIndex < count - 1
                ? () => controller.reorderLayer(element.id, paintIndex + 1)
                : null,
          ),
          StoryEditorButton(
            label: 'Move $name down',
            icon: StoryEditorIcons.chevronDown,
            onPressed: paintIndex > 0
                ? () => controller.reorderLayer(element.id, paintIndex - 1)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Context-sensitive editing controls for the selection, the brush, and
/// selected media. Every canvas transform has a button here too, so editing
/// never requires gestures.
class StoryPropertiesPanel extends StatelessWidget {
  /// Creates a properties panel.
  const StoryPropertiesPanel({required this.controller, super.key});

  /// The editor.
  final StoryEditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.brush]),
      builder: (context, _) {
        final selected = controller.editableSelection;
        final drawing = controller.activeToolId == StoryDrawTool.toolId;
        final sections = <Widget>[
          if (drawing) _BrushControls(controller: controller),
          if (selected.length == 1 && selected.single is TextElement)
            _TextControls(
                controller: controller,
                element: selected.single as TextElement),
          if (selected.length == 1 && selected.single is TimedMediaElement)
            _TrimControls(
                controller: controller,
                element: selected.single as TimedMediaElement),
          if (selected.isNotEmpty) _ArrangeControls(controller: controller),
        ];
        final title = switch (selected) {
          [] => drawing ? 'Brush' : 'Properties',
          [final single] => storyElementName(single),
          _ => '${selected.length} selected',
        };
        return StoryEditorPanel(
          title: title,
          icon: switch (selected) {
            [final single] => storyElementIcon(single),
            _ => StoryEditorIcons.sparkle,
          },
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: sections.isEmpty
              ? const _EmptyProperties()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: sections,
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyProperties extends StatelessWidget {
  const _EmptyProperties();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoryEditorIcon(StoryEditorIcons.select,
                  size: 28, color: StoryEditorColors.muted),
              SizedBox(height: 10),
              Text(
                'Select an element to edit it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: StoryEditorColors.muted),
              ),
            ],
          ),
        ),
      );
}

class _ArrangeControls extends StatelessWidget {
  const _ArrangeControls({required this.controller});

  final StoryEditorController controller;

  void _transformEach(
      StoryElement Function(StoryElement element) change, String label) {
    controller.updateElements(
        [for (final e in controller.editableSelection) change(e)],
        label: label);
  }

  @override
  Widget build(BuildContext context) {
    final count = controller.editableSelection.length;
    final selection = controller.selectedElements;
    final first = controller.editableSelection.firstOrNull;
    final allLocked = selection.isNotEmpty && selection.every((e) => e.locked);
    const quarter = 0.2617993877991494; // 15 degrees
    final scale = first == null ? 1.0 : first.transform.scale;
    final opacity = first == null ? 1.0 : first.opacity;
    final degrees = first == null
        ? 0
        : (first.transform.rotation * 180 / 3.141592653589793).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StoryEditorSectionLabel('Align'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            StoryEditorButtonGroup(children: [
              for (final (alignment, icon, name) in const [
                (StoryAlignment.left, StoryEditorIcons.alignLeft, 'Align left'),
                (
                  StoryAlignment.centerHorizontal,
                  StoryEditorIcons.alignCenter,
                  'Align center'
                ),
                (
                  StoryAlignment.right,
                  StoryEditorIcons.alignRight,
                  'Align right'
                ),
              ])
                StoryEditorButton(
                  label: name,
                  icon: icon,
                  onPressed: () => controller.alignSelection(alignment),
                ),
            ]),
            StoryEditorButtonGroup(children: [
              for (final (alignment, icon, name) in const [
                (StoryAlignment.top, StoryEditorIcons.alignTop, 'Align top'),
                (
                  StoryAlignment.centerVertical,
                  StoryEditorIcons.alignMiddle,
                  'Align middle'
                ),
                (
                  StoryAlignment.bottom,
                  StoryEditorIcons.alignBottom,
                  'Align bottom'
                ),
              ])
                StoryEditorButton(
                  label: name,
                  icon: icon,
                  onPressed: () => controller.alignSelection(alignment),
                ),
            ]),
            if (count >= 3)
              StoryEditorButtonGroup(children: [
                StoryEditorButton(
                  label: 'Distribute horizontally',
                  icon: StoryEditorIcons.distributeHorizontal,
                  onPressed: () => controller
                      .distributeSelection(StoryDistribution.horizontal),
                ),
                StoryEditorButton(
                  label: 'Distribute vertically',
                  icon: StoryEditorIcons.distributeVertical,
                  onPressed: () => controller
                      .distributeSelection(StoryDistribution.vertical),
                ),
              ]),
          ],
        ),
        const StoryEditorSectionLabel('Order'),
        StoryEditorButtonGroup(children: [
          Expanded(
            child: StoryEditorButton(
                label: 'Bring to front',
                icon: StoryEditorIcons.bringToFront,
                onPressed: controller.bringToFront),
          ),
          Expanded(
            child: StoryEditorButton(
                label: 'Bring forward',
                icon: StoryEditorIcons.bringForward,
                onPressed: controller.bringForward),
          ),
          Expanded(
            child: StoryEditorButton(
                label: 'Send backward',
                icon: StoryEditorIcons.sendBackward,
                onPressed: controller.sendBackward),
          ),
          Expanded(
            child: StoryEditorButton(
                label: 'Send to back',
                icon: StoryEditorIcons.sendToBack,
                onPressed: controller.sendToBack),
          ),
        ]),
        const StoryEditorSectionLabel('Transform'),
        StoryEditorStepper(
          title: 'Rotate',
          icon: StoryEditorIcons.rotateRight,
          value: '$degrees°',
          decreaseLabel: 'Rotate left 15 degrees',
          increaseLabel: 'Rotate right 15 degrees',
          onDecrease: () => _transformEach(
              (e) => e.copyWithCommon(
                  transform: e.transform
                      .copyWith(rotation: e.transform.rotation - quarter)),
              'Rotate'),
          onIncrease: () => _transformEach(
              (e) => e.copyWithCommon(
                  transform: e.transform
                      .copyWith(rotation: e.transform.rotation + quarter)),
              'Rotate'),
        ),
        StoryEditorStepper(
          title: 'Scale',
          icon: StoryEditorIcons.scale,
          value: '${(scale * 100).round()}%',
          decreaseLabel: 'Make smaller',
          increaseLabel: 'Make larger',
          onDecrease: () => _transformEach(
              (e) => e.copyWithCommon(
                  transform:
                      e.transform.copyWith(scale: e.transform.scale / 1.1)),
              'Scale'),
          onIncrease: () => _transformEach(
              (e) => e.copyWithCommon(
                  transform:
                      e.transform.copyWith(scale: e.transform.scale * 1.1)),
              'Scale'),
        ),
        StoryEditorStepper(
          title: 'Opacity',
          icon: StoryEditorIcons.opacity,
          value: '${(opacity * 100).round()}%',
          decreaseLabel: 'Less opaque',
          increaseLabel: 'More opaque',
          onDecrease: () => _transformEach(
              (e) =>
                  e.copyWithCommon(opacity: (e.opacity - 0.1).clamp(0.1, 1.0)),
              'Opacity'),
          onIncrease: () => _transformEach(
              (e) =>
                  e.copyWithCommon(opacity: (e.opacity + 0.1).clamp(0.1, 1.0)),
              'Opacity'),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: StoryEditorButton(
                label: 'Flip horizontally',
                icon: StoryEditorIcons.flipHorizontal,
                glyph: 'Flip',
                tonal: true,
                onPressed: () => controller.flipSelection(horizontal: true),
              ),
            ),
            Expanded(
              child: StoryEditorButton(
                label: 'Flip vertically',
                icon: StoryEditorIcons.flipVertical,
                glyph: 'Flip',
                tonal: true,
                onPressed: () => controller.flipSelection(horizontal: false),
              ),
            ),
            Expanded(
              child: StoryEditorButton(
                label: allLocked ? 'Unlock selection' : 'Lock selection',
                icon:
                    allLocked ? StoryEditorIcons.lock : StoryEditorIcons.unlock,
                glyph: allLocked ? 'Locked' : 'Lock',
                tonal: true,
                selected: allLocked ? true : null,
                onPressed: () => controller.setSelectionLocked(!allLocked),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TextControls extends StatelessWidget {
  const _TextControls({required this.controller, required this.element});

  final StoryEditorController controller;
  final TextElement element;

  void _style(StoryTextStyle style) => controller
      .updateElement(element.copyWith(style: style), label: 'Text style');

  static StoryEditorIcons _alignIcon(StoryTextAlign align) => switch (align) {
        StoryTextAlign.left => StoryEditorIcons.textLeft,
        StoryTextAlign.right => StoryEditorIcons.textRight,
        StoryTextAlign.justify => StoryEditorIcons.textJustify,
        _ => StoryEditorIcons.textCenter,
      };

  @override
  Widget build(BuildContext context) {
    final style = element.style;
    final aligns = StoryTextAlign.values;
    final bold = style.fontWeight >= 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StoryEditorSectionLabel('Text'),
        StoryEditorButton(
          label: 'Edit text',
          icon: StoryEditorIcons.draw,
          glyph: 'Edit text',
          tonal: true,
          expand: true,
          onPressed: () => controller.beginTextEditing(element.id),
        ),
        const SizedBox(height: 6),
        StoryEditorStepper(
          title: 'Size',
          icon: StoryEditorIcons.text,
          value: '${style.fontSize.round()}',
          decreaseLabel: 'Smaller text',
          increaseLabel: 'Larger text',
          onDecrease: () => _style(
              style.copyWith(fontSize: (style.fontSize - 8).clamp(8.0, 600.0))),
          onIncrease: () => _style(
              style.copyWith(fontSize: (style.fontSize + 8).clamp(8.0, 600.0))),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            StoryEditorButtonGroup(children: [
              StoryEditorButton(
                label: bold ? 'Regular weight' : 'Bold',
                icon: StoryEditorIcons.bold,
                selected: bold,
                onPressed: () =>
                    _style(style.copyWith(fontWeight: bold ? 400 : 700)),
              ),
              StoryEditorButton(
                label: 'Italic',
                icon: StoryEditorIcons.italic,
                selected: style.italic,
                onPressed: () => _style(style.copyWith(italic: !style.italic)),
              ),
            ]),
            const SizedBox(width: 6),
            StoryEditorButtonGroup(children: [
              StoryEditorButton(
                label: 'Text alignment ${element.align.name}',
                icon: _alignIcon(element.align),
                glyph: element.align.name,
                onPressed: () => controller.updateElement(
                  element.copyWith(
                      align: aligns[(element.align.index + 1) % aligns.length]),
                  label: 'Text alignment',
                ),
              ),
            ]),
          ],
        ),
        const StoryEditorSectionLabel('Color'),
        StorySwatchRow(
          label: 'Text color',
          selected: style.color,
          onSelected: (color) => _style(style.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _BrushControls extends StatelessWidget {
  const _BrushControls({required this.controller});

  final StoryEditorController controller;

  @override
  Widget build(BuildContext context) {
    final brush = controller.brush.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StoryEditorSectionLabel('Brush'),
        StoryEditorStepper(
          title: 'Size',
          icon: StoryEditorIcons.draw,
          value: '${brush.width.round()}',
          valueLabel: 'Brush size ${brush.width.round()}',
          decreaseLabel: 'Thinner brush',
          increaseLabel: 'Thicker brush',
          onDecrease: () => controller.brush.value =
              brush.copyWith(width: (brush.width - 4).clamp(2.0, 120.0)),
          onIncrease: () => controller.brush.value =
              brush.copyWith(width: (brush.width + 4).clamp(2.0, 120.0)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: ExcludeSemantics(
              child: Container(
                width: 120,
                height: (brush.width / 2).clamp(2.0, 30.0),
                decoration: BoxDecoration(
                  color: Color(brush.color.value),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ),
        StorySwatchRow(
          label: 'Brush color',
          selected: brush.color,
          onSelected: (color) =>
              controller.brush.value = brush.copyWith(color: color),
        ),
      ],
    );
  }
}

class _TrimControls extends StatelessWidget {
  const _TrimControls({required this.controller, required this.element});

  final StoryEditorController controller;
  final TimedMediaElement element;

  static const Duration _step = Duration(milliseconds: 500);

  String _seconds(Duration value) =>
      '${(value.inMilliseconds / 1000).toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    final start = element.trimStart;
    final end = element.trimEnd;
    Duration clampStart(Duration value) =>
        value < Duration.zero ? Duration.zero : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StoryEditorSectionLabel('Media timing'),
        StoryEditorStepper(
          title: 'Start',
          icon: StoryEditorIcons.clock,
          value: _seconds(start),
          valueLabel: 'Trim start ${_seconds(start)}',
          decreaseLabel: 'Start earlier',
          increaseLabel: 'Start later',
          onDecrease: start > Duration.zero
              ? () => controller.setMediaTrim(element.id,
                  start: clampStart(start - _step), end: end)
              : null,
          onIncrease: () => controller.setMediaTrim(element.id,
              start: start + _step, end: end),
        ),
        StoryEditorStepper(
          title: 'End',
          icon: StoryEditorIcons.clock,
          value: end == null ? 'Full' : _seconds(end),
          valueLabel:
              end == null ? 'Plays to the end' : 'Trim end ${_seconds(end)}',
          decreaseLabel: 'End earlier',
          increaseLabel: 'End later',
          onDecrease: end != null && end - _step > start
              ? () => controller.setMediaTrim(element.id,
                  start: start, end: end - _step)
              : null,
          onIncrease: () => controller.setMediaTrim(element.id,
              start: start, end: (end ?? start) + _step),
        ),
        const SizedBox(height: 4),
        StoryEditorButton(
          label: 'Play to the end',
          glyph: 'Play to the end',
          tonal: true,
          expand: true,
          onPressed: end == null
              ? null
              : () => controller.setMediaTrim(element.id, start: start),
        ),
      ],
    );
  }
}

/// A row of color swatches.
class StorySwatchRow extends StatelessWidget {
  /// Creates a swatch row.
  const StorySwatchRow({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.colors = storyEditorSwatches,
    super.key,
  });

  /// Describes what the colors apply to.
  final String label;

  /// The current color.
  final StoryColor selected;

  /// Called with the picked color.
  final ValueChanged<StoryColor> onSelected;

  /// The swatches.
  final List<StoryColor> colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final color in colors)
            Semantics(
              button: true,
              selected: color == selected,
              label: '$label ${color.toHex()}',
              onTap: () => onSelected(color),
              child: ExcludeSemantics(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => onSelected(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 30,
                      height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == selected
                              ? StoryEditorColors.accent
                              : const Color(0x00000000),
                          width: 2,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(color.value),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The story timeline: groups, item thumbnails in order, and controls for
/// adding, duplicating, deleting, reordering, timing, and transitions.
class StoryTimelinePanel extends StatelessWidget {
  /// Creates a timeline panel.
  const StoryTimelinePanel({
    required this.controller,
    required this.renderers,
    super.key,
  });

  /// The editor.
  final StoryEditorController controller;

  /// Renders the thumbnails.
  final StoryRendererRegistry renderers;

  /// Transition choices cycled by the transition button; `null` is the
  /// viewer default.
  static const List<String?> transitionCycle = [
    null,
    'none',
    'fade',
    'slide',
    'scale',
    'zoom',
    'cube',
    'horizontalReveal',
    'verticalReveal',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final document = controller.document;
        final group = controller.currentGroup;
        final items = controller.currentGroupItems;
        final current = controller.currentItem;
        final index = items.indexWhere((i) => i.id == current?.id);
        final duration = current?.duration;
        final seconds = duration is FixedItemDuration
            ? duration.duration.inMilliseconds / 1000
            : null;
        final transition = current?.transition?.type;
        final cycle = transitionCycle;
        final nextTransition =
            cycle[(cycle.indexOf(transition) + 1) % cycle.length];

        return DecoratedBox(
          decoration: BoxDecoration(
            color: StoryEditorColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StoryEditorColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Row(
                  children: [
                    for (final g in document.groups)
                      StoryEditorButton(
                        label: 'Group ${g.title ?? g.id}',
                        icon: StoryEditorIcons.person,
                        glyph: g.title ??
                            'Group ${document.groups.indexOf(g) + 1}',
                        selected: g.id == group?.id,
                        tonal: true,
                        onPressed: g.items.isEmpty
                            ? null
                            : () => controller.setCurrentItem(g.items.first.id),
                      ),
                    StoryEditorButton(
                      label: 'Add group',
                      icon: StoryEditorIcons.plus,
                      glyph: 'Group',
                      onPressed: () {
                        final id = controller.addGroup();
                        final added = controller.document.groupById(id);
                        if (added != null && added.items.isNotEmpty) {
                          controller.setCurrentItem(added.items.first.id);
                        }
                      },
                    ),
                    const _Divider(),
                    StoryEditorButton(
                      label: 'Add story',
                      icon: StoryEditorIcons.plus,
                      glyph: 'Story',
                      tonal: true,
                      onPressed: controller.addItem,
                    ),
                    StoryEditorButton(
                      label: 'Duplicate story',
                      icon: StoryEditorIcons.duplicate,
                      onPressed: current == null
                          ? null
                          : () => controller.duplicateItem(current.id),
                    ),
                    StoryEditorButton(
                      label: 'Delete story',
                      icon: StoryEditorIcons.delete,
                      onPressed:
                          current == null || document.allItems.length <= 1
                              ? null
                              : () => controller.removeItem(current.id),
                    ),
                    StoryEditorButton(
                      label: 'Move story earlier',
                      icon: StoryEditorIcons.chevronLeft,
                      onPressed: current == null || index <= 0
                          ? null
                          : () => controller.moveItem(current.id, index - 1),
                    ),
                    StoryEditorButton(
                      label: 'Move story later',
                      icon: StoryEditorIcons.chevronRight,
                      onPressed: current == null || index >= items.length - 1
                          ? null
                          : () => controller.moveItem(current.id, index + 1),
                    ),
                    const _Divider(),
                    const StoryEditorIcon(StoryEditorIcons.clock,
                        size: 16, color: StoryEditorColors.muted),
                    const SizedBox(width: 6),
                    StoryEditorButtonGroup(children: [
                      StoryEditorButton(
                        label: 'Shorter',
                        icon: StoryEditorIcons.minus,
                        onPressed:
                            current == null || seconds == null || seconds <= 1
                                ? null
                                : () => controller.setItemDuration(
                                    current.id,
                                    FixedItemDuration(Duration(
                                        milliseconds:
                                            ((seconds - 1) * 1000).round()))),
                      ),
                      Semantics(
                        label: seconds == null
                            ? 'Duration automatic'
                            : 'Duration ${seconds.toStringAsFixed(0)} seconds',
                        child: ExcludeSemantics(
                          child: SizedBox(
                            width: 44,
                            child: Text(
                              seconds == null
                                  ? 'Auto'
                                  : '${seconds.toStringAsFixed(0)}s',
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      StoryEditorButton(
                        label: 'Longer',
                        icon: StoryEditorIcons.plus,
                        onPressed: current == null
                            ? null
                            : () => controller.setItemDuration(
                                current.id,
                                FixedItemDuration(Duration(
                                    milliseconds: (((seconds ?? 4) + 1) * 1000)
                                        .round()))),
                      ),
                    ]),
                    const SizedBox(width: 6),
                    StoryEditorButton(
                      label: 'Transition ${transition ?? 'default'}, change',
                      icon: StoryEditorIcons.sparkle,
                      glyph: transition ?? 'default',
                      tonal: true,
                      onPressed: current == null
                          ? null
                          : () => controller.setItemTransition(
                              current.id,
                              nextTransition == null
                                  ? null
                                  : StoryTransitionConfiguration.preset(
                                      nextTransition)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  children: [
                    for (final (i, item) in items.indexed)
                      _TimelineThumbnail(
                        controller: controller,
                        renderers: renderers,
                        document: document,
                        itemId: item.id,
                        index: i,
                        selected: item.id == current?.id,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineThumbnail extends StatelessWidget {
  const _TimelineThumbnail({
    required this.controller,
    required this.renderers,
    required this.document,
    required this.itemId,
    required this.index,
    required this.selected,
  });

  final StoryEditorController controller;
  final StoryRendererRegistry renderers;
  final StoryDocument document;
  final String itemId;
  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final item =
        controller.document.allItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      selected: selected,
      label: 'Story ${index + 1}',
      onTap: () => controller.setCurrentItem(itemId),
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => controller.setCurrentItem(itemId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                gradient: selected ? StoryEditorColors.accentGradient : null,
                color: selected ? null : StoryEditorColors.border,
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x557C5CFF),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9.5),
                child: AspectRatio(
                  aspectRatio: document.canvas.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        child: StoryItemView(
                          document: document,
                          item: item,
                          registry: renderers,
                          mode: StoryRenderMode.editor,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0x99000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: StoryEditorColors.text,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
