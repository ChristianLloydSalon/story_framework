import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../06_story_editor/main.dart' show PreviewPage;
import '../shared.dart';

/// Run: flutter run -t lib/examples/11_mobile_editor/main.dart
void main() => runApp(const ExampleApp(example: mobileEditorExample));

const mobileEditorExample = StoryExample(
  number: 11,
  title: 'Mobile story editor',
  description: 'A full-screen, phone-style editor built on StoryEditor with a '
      'custom layoutBuilder: floating tool buttons, an emoji sheet, drawing '
      'with a color row, and drag-to-trash deletion. Drag an element onto '
      'the trash can to delete it; undo brings it back.',
  page: MobileEditorPage(),
);

final StoryDocument mobileDraft = StoryDocument(
  id: 'draft',
  groups: [
    StoryGroup(id: 'me', title: 'You', items: [
      StoryItem(
        id: 'draft-1',
        background: gradient(0xFF0F2027, 0xFF2C5364),
        elements: [
          StickerElement(
            id: 'wave',
            transform: box(540, 960, 320, 320),
            sticker: const EmojiSticker('👋'),
          ),
        ],
      ),
    ]),
  ],
);

class MobileEditorPage extends StatefulWidget {
  const MobileEditorPage({super.key});

  @override
  State<MobileEditorPage> createState() => _MobileEditorPageState();
}

class _MobileEditorPageState extends State<MobileEditorPage> {
  // Only the tools this editor offers; stickers come from the emoji sheet.
  final StoryEditorToolRegistry _tools = StoryEditorToolRegistry([
    StorySelectTool(),
    StoryTextTool(),
    StoryDrawTool(),
    StoryEraserTool(),
  ]);

  @override
  void dispose() {
    _tools.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: StoryEditor(
            document: mobileDraft,
            tools: _tools,
            layoutBuilder: (context, parts) => MobileEditorLayout(parts: parts),
          ),
        ),
      );
}

/// A full-screen canvas with floating controls.
class MobileEditorLayout extends StatefulWidget {
  const MobileEditorLayout({required this.parts, super.key});

  final StoryEditorParts parts;

  @override
  State<MobileEditorLayout> createState() => _MobileEditorLayoutState();
}

class _MobileEditorLayoutState extends State<MobileEditorLayout> {
  final GlobalKey _trashKey = GlobalKey();
  String? _editingTextId;

  StoryEditorController get _controller => widget.parts.controller;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onEditorChanged)
      ..elementDrag.addListener(_onDrag);
  }

  @override
  void didUpdateWidget(MobileEditorLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.parts.controller;
    if (!identical(old, _controller)) {
      old
        ..removeListener(_onEditorChanged)
        ..elementDrag.removeListener(_onDrag);
      _controller
        ..addListener(_onEditorChanged)
        ..elementDrag.addListener(_onDrag);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (!controller.isDisposed) {
      controller
        ..removeListener(_onEditorChanged)
        ..elementDrag.removeListener(_onDrag);
    }
    super.dispose();
  }

  /// Removes text that was left empty when typing finished.
  void _onEditorChanged() {
    final controller = _controller;
    final previous = _editingTextId;
    _editingTextId = controller.editingTextId;
    if (previous == null || previous == controller.editingTextId) return;
    final element = controller.elementById(previous);
    if (element is TextElement && element.text.trim().isEmpty) {
      controller
        ..select([previous])
        ..deleteSelection();
    }
  }

  /// Arms drop-to-delete while the pointer is over the trash can.
  void _onDrag() {
    final drag = _controller.elementDrag.value;
    final trash = _trashKey.currentContext;
    var hot = false;
    // The trash only exists during a drag; measure it only then.
    if (drag != null && trash != null && trash.mounted) {
      final target = trash.findRenderObject();
      if (target is RenderBox && target.hasSize) {
        final rect =
            (target.localToGlobal(Offset.zero) & target.size).inflate(24);
        hot = rect.contains(drag.globalPosition);
      }
    }
    if (_controller.dropToDelete.value != hot) {
      _controller.dropToDelete.value = hot;
    }
    if (mounted) setState(() {});
  }

  void _addText() {
    final controller = _controller;
    final id = controller.newId('text');
    controller
      ..setActiveTool(StorySelectTool.toolId)
      ..addElement(TextElement(
        id: id,
        transform: box(540, 820, 940, 260),
        text: '',
        style: StoryTextStyle(
          fontSize: 104,
          fontWeight: 800,
          shadows: const [
            StoryShadow(offset: StoryPoint(0, 4), blurRadius: 14),
          ],
        ),
      ))
      ..beginTextEditing(id);
  }

  Future<void> _addEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      showDragHandle: true,
      builder: (context) => const EmojiSheet(),
    );
    if (emoji == null || !mounted) return;
    final controller = _controller;
    controller
      ..setActiveTool(StorySelectTool.toolId)
      ..addElement(StickerElement(
        id: controller.newId('sticker'),
        transform: box(540, 960, 300, 300),
        sticker: EmojiSticker(emoji),
      ));
  }

  void _preview() {
    final document = _controller.document;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => PreviewPage(document: document),
      ),
    );
  }

  void _share() {
    final count = _controller.currentItem?.elements.length ?? 0;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Story shared with $count element(s).'),
      ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          final controller = _controller;
          final dragging = controller.elementDrag.value != null;
          final hot = controller.dropToDelete.value;
          final drawing = controller.activeToolId == StoryDrawTool.toolId ||
              controller.activeToolId == StoryEraserTool.eraserToolId;
          final typing = controller.editingTextId != null;
          final selected = controller.editableSelection;
          final selectedText =
              selected.length == 1 && selected.single is TextElement
                  ? selected.single as TextElement
                  : null;
          final showChrome = !dragging && !typing;

          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 76),
                  child: widget.parts.canvas,
                ),
              ),

              // Close.
              _Fade(
                visible: showChrome,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: RoundButton(
                      label: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),

              // Tool rail.
              _Fade(
                visible: showChrome && !drawing,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RoundButton(
                          label: 'Add text',
                          glyph: 'Aa',
                          onPressed: _addText,
                        ),
                        RoundButton(
                          label: 'Add emoji',
                          icon: const StoryEditorIcon(StoryEditorIcons.sticker,
                              color: Colors.white),
                          onPressed: _addEmoji,
                        ),
                        RoundButton(
                          label: 'Draw',
                          icon: const StoryEditorIcon(StoryEditorIcons.draw,
                              color: Colors.white),
                          onPressed: () =>
                              controller.setActiveTool(StoryDrawTool.toolId),
                        ),
                        RoundButton(
                          label: 'Undo',
                          icon: const StoryEditorIcon(StoryEditorIcons.undo,
                              color: Colors.white),
                          onPressed:
                              controller.canUndo ? controller.undo : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Drawing controls.
              if (drawing && !dragging) ...[
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RoundButton(
                          label: 'Undo',
                          icon: const StoryEditorIcon(StoryEditorIcons.undo,
                              color: Colors.white),
                          onPressed:
                              controller.canUndo ? controller.undo : null,
                        ),
                        RoundButton(
                          label: controller.activeToolId ==
                                  StoryEraserTool.eraserToolId
                              ? 'Use pen'
                              : 'Use eraser',
                          icon: StoryEditorIcon(
                              controller.activeToolId ==
                                      StoryEraserTool.eraserToolId
                                  ? StoryEditorIcons.draw
                                  : StoryEditorIcons.eraser,
                              color: Colors.white),
                          onPressed: () => controller.setActiveTool(
                              controller.activeToolId ==
                                      StoryEraserTool.eraserToolId
                                  ? StoryDrawTool.toolId
                                  : StoryEraserTool.eraserToolId),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: () =>
                              controller.setActiveTool(StorySelectTool.toolId),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 92),
                    child: ValueListenableBuilder<StoryBrush>(
                      valueListenable: controller.brush,
                      builder: (context, brush, child) => StorySwatchRow(
                        label: 'Brush color',
                        selected: brush.color,
                        onSelected: (color) => controller.brush.value =
                            brush.copyWith(color: color),
                      ),
                    ),
                  ),
                ),
              ],

              // Text color, while text is selected or being typed.
              if (selectedText != null && !drawing && !dragging)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: typing ? 16 : 92),
                    child: StorySwatchRow(
                      label: 'Text color',
                      selected: selectedText.style.color,
                      onSelected: (color) => controller.updateElement(
                        selectedText.copyWith(
                            style: selectedText.style.copyWith(color: color)),
                        label: 'Text color',
                      ),
                    ),
                  ),
                ),

              // Preview and share.
              _Fade(
                visible: showChrome && !drawing,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _preview,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          icon: const StoryEditorIcon(StoryEditorIcons.visible,
                              size: 18, color: Colors.white),
                          label: const Text('Preview'),
                        ),
                        const Spacer(),
                        ShareButton(onPressed: _share),
                      ],
                    ),
                  ),
                ),
              ),

              // Trash, while dragging.
              if (dragging)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: TrashTarget(key: _trashKey, hot: hot),
                  ),
                ),
            ],
          );
        },
      );
}

/// Fades a control in and out, and ignores touches while hidden.
class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: child,
        ),
      );
}

/// A translucent circular button floating over the story.
class RoundButton extends StatelessWidget {
  const RoundButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.glyph,
    super.key,
  });

  final String label;
  final Widget? icon;
  final String? glyph;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final glyph = this.glyph;
    final enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.black.withAlpha(0x66),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 46,
                child: Center(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.4,
                    child: glyph != null
                        ? Text(
                            glyph,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : icon,
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

/// The delete target shown at the bottom while an element is dragged.
class TrashTarget extends StatelessWidget {
  const TrashTarget({required this.hot, super.key});

  /// Whether the dragged element will be deleted if dropped now.
  final bool hot;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: hot ? 'Release to delete' : 'Drag here to delete',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: hot ? 76 : 60,
          height: hot ? 76 : 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hot ? const Color(0xFFFF4F5E) : Colors.black54,
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: Center(
            child: StoryEditorIcon(StoryEditorIcons.delete,
                size: hot ? 30 : 24, color: Colors.white),
          ),
        ),
      );
}

/// The primary action at the bottom right.
class ShareButton extends StatelessWidget {
  const ShareButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: StoryEditorColors.accentGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          child: const Text('Share',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

/// A grid of emojis; pops with the chosen one.
class EmojiSheet extends StatelessWidget {
  const EmojiSheet({super.key});

  static const List<String> emojis = [
    '😀', '😂', '🥰', '😎', '🤩', '😴', '🤯', '🥳', //
    '👋', '👍', '🙌', '👏', '🙏', '💪', '✌️', '🤞', //
    '❤️', '🔥', '✨', '⭐', '🌈', '☀️', '🌙', '⚡', //
    '🎉', '🎈', '🎁', '🎵', '📸', '✈️', '🌴', '🍕', //
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        child: GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            for (final emoji in emojis)
              Semantics(
                button: true,
                label: 'Add $emoji',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(emoji),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
