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

/// Colors of the default editor UI.
abstract final class StoryEditorColors {
  /// Editor background.
  static const Color background = Color(0xFF16161B);

  /// Panel background.
  static const Color panel = Color(0xFF202027);

  /// Button background.
  static const Color button = Color(0xFF2C2C35);

  /// Primary text.
  static const Color text = Color(0xFFF2F2F5);

  /// Secondary text.
  static const Color muted = Color(0xFF9A9AA8);

  /// Selection and focus.
  static const Color accent = Color(0xFF4C8DFF);
}

/// Swatches offered for text and brush colors.
const List<StoryColor> storyEditorSwatches = [
  StoryColor(0xFFFFFFFF),
  StoryColor(0xFF000000),
  StoryColor(0xFFFF4F5E),
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
    TextElement(:final text) =>
      text.trim().isEmpty ? 'Text' : '“${text.trim()}”',
    StickerElement(sticker: EmojiSticker(:final emoji)) => 'Sticker $emoji',
    InteractiveElement(:final interaction) =>
      '${interaction.kind[0].toUpperCase()}${interaction.kind.substring(1)}',
    _ => '${element.type[0].toUpperCase()}${element.type.substring(1)}',
  };
}

/// A compact, focusable, screen-reader-labeled editor button.
///
/// Enter and Space activate it when focused.
class StoryEditorButton extends StatefulWidget {
  /// Creates a button showing [glyph].
  const StoryEditorButton({
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.selected,
    super.key,
  });

  /// Spoken by screen readers (and shown as a tooltip-like semantics label).
  final String label;

  /// Short visible text, such as "T" or "Undo".
  final String glyph;

  /// Called when activated; `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether the toggle is on (for example the current tool), or `null` for
  /// a plain button that has no on/off state.
  final bool? selected;

  @override
  State<StoryEditorButton> createState() => _StoryEditorButtonState();
}

class _StoryEditorButtonState extends State<StoryEditorButton> {
  bool _focused = false;

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
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _activate : null,
          child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.selected ?? false
                    ? StoryEditorColors.accent
                    : StoryEditorColors.button,
                borderRadius: BorderRadius.circular(8),
                border: _focused
                    ? Border.all(color: StoryEditorColors.text, width: 2)
                    : null,
              ),
              child: Text(
                widget.glyph,
                style: TextStyle(
                  color: enabled
                      ? StoryEditorColors.text
                      : StoryEditorColors.muted.withAlpha(0x88),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Semantics(
          header: true,
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: StoryEditorColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
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
        return ColoredBox(
          color: StoryEditorColors.panel,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final tool in tools.tools)
                  StoryEditorButton(
                    label: '${tool.label} tool',
                    glyph: tool.symbol,
                    selected: controller.activeToolId == tool.id,
                    onPressed: () => controller.setActiveTool(tool.id),
                  ),
                const SizedBox(width: 12),
                StoryEditorButton(
                  label: undo == null ? 'Undo' : 'Undo $undo',
                  glyph: '↶',
                  onPressed: controller.canUndo ? controller.undo : null,
                ),
                StoryEditorButton(
                  label: redo == null ? 'Redo' : 'Redo $redo',
                  glyph: '↷',
                  onPressed: controller.canRedo ? controller.redo : null,
                ),
                const SizedBox(width: 12),
                StoryEditorButton(
                  label: 'Duplicate selection',
                  glyph: '⧉',
                  onPressed:
                      hasSelection ? controller.duplicateSelection : null,
                ),
                StoryEditorButton(
                  label: 'Delete selection',
                  glyph: '🗑',
                  onPressed: hasSelection ? controller.deleteSelection : null,
                ),
              ],
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
        return ColoredBox(
          color: StoryEditorColors.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StoryEditorSectionLabel('Layers'),
              Expanded(
                child: layers.isEmpty
                    ? const Center(
                        child: Text('No layers',
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
    return Container(
      color: selected ? StoryEditorColors.accent.withAlpha(0x44) : null,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: StoryEditorButton(
              label: 'Select layer $name',
              glyph: name,
              selected: selected,
              onPressed: () => controller.select([element.id]),
            ),
          ),
          StoryEditorButton(
            label: element.visible ? 'Hide $name' : 'Show $name',
            glyph: element.visible ? '◉' : '○',
            onPressed: () => controller.toggleVisible(element.id),
          ),
          StoryEditorButton(
            label: element.locked ? 'Unlock $name' : 'Lock $name',
            glyph: element.locked ? '🔒' : '🔓',
            onPressed: () => controller.toggleLocked(element.id),
          ),
          StoryEditorButton(
            label: 'Move $name up',
            glyph: '▲',
            onPressed: paintIndex < count - 1
                ? () => controller.reorderLayer(element.id, paintIndex + 1)
                : null,
          ),
          StoryEditorButton(
            label: 'Move $name down',
            glyph: '▼',
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
          if (selected.isNotEmpty) _ArrangeControls(controller: controller),
          if (selected.length == 1 && selected.single is TextElement)
            _TextControls(
                controller: controller,
                element: selected.single as TextElement),
          if (selected.length == 1 && selected.single is TimedMediaElement)
            _TrimControls(
                controller: controller,
                element: selected.single as TimedMediaElement),
        ];
        return ColoredBox(
          color: StoryEditorColors.panel,
          child: sections.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Select an element to edit it.',
                      style: TextStyle(color: StoryEditorColors.muted)),
                )
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
    final allLocked = selection.isNotEmpty && selection.every((e) => e.locked);
    const quarter = 0.2617993877991494; // 15 degrees
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StoryEditorSectionLabel('Arrange'),
        Wrap(
          children: [
            for (final (alignment, glyph, name) in const [
              (StoryAlignment.left, '⇤', 'Align left'),
              (StoryAlignment.centerHorizontal, '↔', 'Align center'),
              (StoryAlignment.right, '⇥', 'Align right'),
              (StoryAlignment.top, '⤒', 'Align top'),
              (StoryAlignment.centerVertical, '↕', 'Align middle'),
              (StoryAlignment.bottom, '⤓', 'Align bottom'),
            ])
              StoryEditorButton(
                label: name,
                glyph: glyph,
                onPressed: () => controller.alignSelection(alignment),
              ),
            if (count >= 3) ...[
              StoryEditorButton(
                label: 'Distribute horizontally',
                glyph: '⋯',
                onPressed: () => controller
                    .distributeSelection(StoryDistribution.horizontal),
              ),
              StoryEditorButton(
                label: 'Distribute vertically',
                glyph: '⋮',
                onPressed: () =>
                    controller.distributeSelection(StoryDistribution.vertical),
              ),
            ],
          ],
        ),
        Wrap(
          children: [
            StoryEditorButton(
                label: 'Bring to front',
                glyph: 'Front',
                onPressed: controller.bringToFront),
            StoryEditorButton(
                label: 'Bring forward',
                glyph: 'Up',
                onPressed: controller.bringForward),
            StoryEditorButton(
                label: 'Send backward',
                glyph: 'Down',
                onPressed: controller.sendBackward),
            StoryEditorButton(
                label: 'Send to back',
                glyph: 'Back',
                onPressed: controller.sendToBack),
          ],
        ),
        Wrap(
          children: [
            StoryEditorButton(
              label: 'Rotate left 15 degrees',
              glyph: '⟲',
              onPressed: () => _transformEach(
                  (e) => e.copyWithCommon(
                      transform: e.transform
                          .copyWith(rotation: e.transform.rotation - quarter)),
                  'Rotate'),
            ),
            StoryEditorButton(
              label: 'Rotate right 15 degrees',
              glyph: '⟳',
              onPressed: () => _transformEach(
                  (e) => e.copyWithCommon(
                      transform: e.transform
                          .copyWith(rotation: e.transform.rotation + quarter)),
                  'Rotate'),
            ),
            StoryEditorButton(
              label: 'Make smaller',
              glyph: '−',
              onPressed: () => _transformEach(
                  (e) => e.copyWithCommon(
                      transform:
                          e.transform.copyWith(scale: e.transform.scale / 1.1)),
                  'Scale'),
            ),
            StoryEditorButton(
              label: 'Make larger',
              glyph: '+',
              onPressed: () => _transformEach(
                  (e) => e.copyWithCommon(
                      transform:
                          e.transform.copyWith(scale: e.transform.scale * 1.1)),
                  'Scale'),
            ),
            StoryEditorButton(
              label: 'Flip horizontally',
              glyph: '⇋',
              onPressed: () => controller.flipSelection(horizontal: true),
            ),
            StoryEditorButton(
              label: 'Flip vertically',
              glyph: '⇵',
              onPressed: () => controller.flipSelection(horizontal: false),
            ),
            StoryEditorButton(
              label: 'Less opaque',
              glyph: '◐−',
              onPressed: () => _transformEach(
                  (e) => e.copyWithCommon(
                      opacity: (e.opacity - 0.1).clamp(0.1, 1.0)),
                  'Opacity'),
            ),
            StoryEditorButton(
              label: 'More opaque',
              glyph: '◐+',
              onPressed: () => _transformEach(
                  (e) => e.copyWithCommon(
                      opacity: (e.opacity + 0.1).clamp(0.1, 1.0)),
                  'Opacity'),
            ),
            StoryEditorButton(
              label: allLocked ? 'Unlock selection' : 'Lock selection',
              glyph: allLocked ? 'Unlock' : 'Lock',
              onPressed: () => controller.setSelectionLocked(!allLocked),
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

  @override
  Widget build(BuildContext context) {
    final style = element.style;
    final aligns = StoryTextAlign.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StoryEditorSectionLabel('Text'),
        Wrap(
          children: [
            StoryEditorButton(
              label: 'Edit text',
              glyph: 'Edit',
              onPressed: () => controller.beginTextEditing(element.id),
            ),
            StoryEditorButton(
              label: 'Smaller text',
              glyph: 'A−',
              onPressed: () => _style(style.copyWith(
                  fontSize: (style.fontSize - 8).clamp(8.0, 600.0))),
            ),
            StoryEditorButton(
              label: 'Larger text',
              glyph: 'A+',
              onPressed: () => _style(style.copyWith(
                  fontSize: (style.fontSize + 8).clamp(8.0, 600.0))),
            ),
            StoryEditorButton(
              label: style.fontWeight >= 700 ? 'Regular weight' : 'Bold',
              glyph: 'B',
              selected: style.fontWeight >= 700,
              onPressed: () => _style(style.copyWith(
                  fontWeight: style.fontWeight >= 700 ? 400 : 700)),
            ),
            StoryEditorButton(
              label: 'Italic',
              glyph: 'I',
              selected: style.italic,
              onPressed: () => _style(style.copyWith(italic: !style.italic)),
            ),
            StoryEditorButton(
              label: 'Text alignment ${element.align.name}',
              glyph: '≡ ${element.align.name}',
              onPressed: () => controller.updateElement(
                element.copyWith(
                    align: aligns[(element.align.index + 1) % aligns.length]),
                label: 'Text alignment',
              ),
            ),
          ],
        ),
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
        Wrap(
          children: [
            StoryEditorButton(
              label: 'Thinner brush',
              glyph: '−',
              onPressed: () => controller.brush.value =
                  brush.copyWith(width: (brush.width - 4).clamp(2.0, 120.0)),
            ),
            StoryEditorButton(
              label: 'Brush size ${brush.width.round()}',
              glyph: '${brush.width.round()}',
              onPressed: null,
            ),
            StoryEditorButton(
              label: 'Thicker brush',
              glyph: '+',
              onPressed: () => controller.brush.value =
                  brush.copyWith(width: (brush.width + 4).clamp(2.0, 120.0)),
            ),
          ],
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
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StoryEditorButton(
              label: 'Start earlier',
              glyph: '−',
              onPressed: start > Duration.zero
                  ? () => controller.setMediaTrim(element.id,
                      start: clampStart(start - _step), end: end)
                  : null,
            ),
            StoryEditorButton(
                label: 'Trim start ${_seconds(start)}',
                glyph: 'Start ${_seconds(start)}',
                onPressed: null),
            StoryEditorButton(
              label: 'Start later',
              glyph: '+',
              onPressed: () => controller.setMediaTrim(element.id,
                  start: start + _step, end: end),
            ),
            StoryEditorButton(
              label: 'End earlier',
              glyph: '−',
              onPressed: end != null && end - _step > start
                  ? () => controller.setMediaTrim(element.id,
                      start: start, end: end - _step)
                  : null,
            ),
            StoryEditorButton(
                label: end == null
                    ? 'Plays to the end'
                    : 'Trim end ${_seconds(end)}',
                glyph: end == null ? 'End: full' : 'End ${_seconds(end)}',
                onPressed: null),
            StoryEditorButton(
              label: 'End later',
              glyph: '+',
              onPressed: () => controller.setMediaTrim(element.id,
                  start: start, end: (end ?? start) + _step),
            ),
            StoryEditorButton(
              label: 'Play to the end',
              glyph: 'Full',
              onPressed: end == null
                  ? null
                  : () => controller.setMediaTrim(element.id, start: start),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        children: [
          for (final color in colors)
            Semantics(
              button: true,
              selected: color == selected,
              label: '$label ${color.toHex()}',
              onTap: () => onSelected(color),
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: () => onSelected(color),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Color(color.value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color == selected
                            ? StoryEditorColors.accent
                            : StoryEditorColors.muted,
                        width: color == selected ? 3 : 1,
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

        return ColoredBox(
          color: StoryEditorColors.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (final g in document.groups)
                      StoryEditorButton(
                        label: 'Group ${g.title ?? g.id}',
                        glyph: g.title ??
                            'Group ${document.groups.indexOf(g) + 1}',
                        selected: g.id == group?.id,
                        onPressed: g.items.isEmpty
                            ? null
                            : () => controller.setCurrentItem(g.items.first.id),
                      ),
                    StoryEditorButton(
                      label: 'Add group',
                      glyph: '+ Group',
                      onPressed: () {
                        final id = controller.addGroup();
                        final added = controller.document.groupById(id);
                        if (added != null && added.items.isNotEmpty) {
                          controller.setCurrentItem(added.items.first.id);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    StoryEditorButton(
                      label: 'Add story',
                      glyph: '+ Story',
                      onPressed: controller.addItem,
                    ),
                    StoryEditorButton(
                      label: 'Duplicate story',
                      glyph: '⧉',
                      onPressed: current == null
                          ? null
                          : () => controller.duplicateItem(current.id),
                    ),
                    StoryEditorButton(
                      label: 'Delete story',
                      glyph: '✕',
                      onPressed:
                          current == null || document.allItems.length <= 1
                              ? null
                              : () => controller.removeItem(current.id),
                    ),
                    StoryEditorButton(
                      label: 'Move story earlier',
                      glyph: '◀',
                      onPressed: current == null || index <= 0
                          ? null
                          : () => controller.moveItem(current.id, index - 1),
                    ),
                    StoryEditorButton(
                      label: 'Move story later',
                      glyph: '▶',
                      onPressed: current == null || index >= items.length - 1
                          ? null
                          : () => controller.moveItem(current.id, index + 1),
                    ),
                    const SizedBox(width: 12),
                    StoryEditorButton(
                      label: 'Shorter',
                      glyph: '−',
                      onPressed:
                          current == null || seconds == null || seconds <= 1
                              ? null
                              : () => controller.setItemDuration(
                                  current.id,
                                  FixedItemDuration(Duration(
                                      milliseconds:
                                          ((seconds - 1) * 1000).round()))),
                    ),
                    StoryEditorButton(
                      label: seconds == null
                          ? 'Duration automatic'
                          : 'Duration ${seconds.toStringAsFixed(0)} seconds',
                      glyph: seconds == null
                          ? 'Auto'
                          : '${seconds.toStringAsFixed(0)}s',
                      onPressed: null,
                    ),
                    StoryEditorButton(
                      label: 'Longer',
                      glyph: '+',
                      onPressed: current == null
                          ? null
                          : () => controller.setItemDuration(
                              current.id,
                              FixedItemDuration(Duration(
                                  milliseconds:
                                      (((seconds ?? 4) + 1) * 1000).round()))),
                    ),
                    StoryEditorButton(
                      label: 'Transition ${transition ?? 'default'}, change',
                      glyph: '✦ ${transition ?? 'default'}',
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
                  padding: const EdgeInsets.all(6),
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
        child: GestureDetector(
          onTap: () => controller.setCurrentItem(itemId),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? StoryEditorColors.accent
                    : StoryEditorColors.button,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
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
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: StoryEditorColors.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 3)],
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
    );
  }
}
