import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../composition/document/story_document.dart';
import '../../configuration/editor/story_editor_config.dart';
import '../../rendering/options/story_render_options.dart';
import '../../rendering/registry/story_renderer_registry.dart';
import '../canvas/story_editor_canvas.dart';
import '../controller/story_editor_controller.dart';
import '../tools/builtin_tools.dart';
import '../tools/story_editor_tool.dart';
import 'editor_controls.dart';
import 'editor_icons.dart';

/// Builds one part of the editor UI.
typedef StoryEditorPartBuilder = Widget Function(
    BuildContext context, StoryEditorController controller);

/// Arranges the editor's parts; replaces the whole default layout.
typedef StoryEditorLayoutBuilder = Widget Function(
    BuildContext context, StoryEditorParts parts);

/// The pieces of the editor, passed to a custom layout.
@immutable
final class StoryEditorParts {
  /// Creates the parts.
  const StoryEditorParts({
    required this.controller,
    required this.toolbar,
    required this.canvas,
    required this.layers,
    required this.properties,
    required this.timeline,
  });

  /// The editor controller.
  final StoryEditorController controller;

  /// Tool and history buttons.
  final Widget toolbar;

  /// The editing surface.
  final Widget canvas;

  /// The layers list.
  final Widget layers;

  /// Selection-dependent controls.
  final Widget properties;

  /// Story items, durations, and transitions.
  final Widget timeline;
}

/// A complete story editor: canvas, tools, layers, properties, and timeline.
///
/// ```dart
/// StoryEditor(
///   document: draft,
///   onChanged: (document) => saveDraft(document),
///   imagePicker: () async => pickImageFromGallery(),
/// )
/// ```
///
/// Pass [controller] to drive the editor yourself; otherwise the editor
/// creates and owns one for [document] (or a blank story). Every part can be
/// replaced with the part builders or [layoutBuilder]; the default editor is
/// optional, and `StoryEditorController` plus `StoryEditorCanvas` can be
/// used on their own.
///
/// Keyboard shortcuts (when [StoryEditorConfig.keyboardShortcuts] is on):
/// Ctrl/Cmd+Z undo, Ctrl/Cmd+Shift+Z or Ctrl+Y redo, Ctrl/Cmd+D duplicate,
/// Ctrl/Cmd+A select all, Delete/Backspace delete, arrows nudge (Shift for
/// larger steps), `]` / `[` bring forward / send backward, Escape clears
/// the selection.
class StoryEditor extends StatefulWidget {
  /// Creates an editor.
  const StoryEditor({
    this.document,
    this.controller,
    this.onChanged,
    this.config = const StoryEditorConfig(),
    this.renderers,
    this.renderOptions = const StoryRenderOptions(),
    this.tools,
    this.imagePicker,
    this.videoPicker,
    this.stickerPicker,
    this.toolbarBuilder,
    this.layersBuilder,
    this.propertiesBuilder,
    this.timelineBuilder,
    this.layoutBuilder,
    super.key,
  });

  /// The document to edit when the editor owns its controller.
  final StoryDocument? document;

  /// An external controller; the caller owns and disposes it.
  final StoryEditorController? controller;

  /// Called with the new document after every change, including undo/redo.
  final ValueChanged<StoryDocument>? onChanged;

  /// Editing behavior for the owned controller.
  final StoryEditorConfig config;

  /// Element renderers, or `null` for the built-in ones.
  final StoryRendererRegistry? renderers;

  /// Rendering options for the canvas.
  final StoryRenderOptions renderOptions;

  /// Tools, or `null` for the defaults (with image/video tools when pickers
  /// are given).
  final StoryEditorToolRegistry? tools;

  /// Picks images for the default image tool.
  final StoryMediaPicker? imagePicker;

  /// Picks videos for the default video tool.
  final StoryMediaPicker? videoPicker;

  /// Picks stickers for the default sticker tool.
  final StoryStickerPicker? stickerPicker;

  /// Replaces the default [StoryEditorToolbar].
  final StoryEditorPartBuilder? toolbarBuilder;

  /// Replaces the default [StoryLayersPanel].
  final StoryEditorPartBuilder? layersBuilder;

  /// Replaces the default [StoryPropertiesPanel].
  final StoryEditorPartBuilder? propertiesBuilder;

  /// Replaces the default [StoryTimelinePanel].
  final StoryEditorPartBuilder? timelineBuilder;

  /// Replaces the default [StoryEditorDefaultLayout].
  final StoryEditorLayoutBuilder? layoutBuilder;

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<StoryEditor> {
  StoryEditorController? _ownedController;
  StoryRendererRegistry? _ownedRenderers;
  StoryEditorToolRegistry? _ownedTools;
  StoryEditorController? _listening;
  StoryDocument? _lastDocument;

  StoryEditorController get _controller =>
      widget.controller ??
      (_ownedController ??= StoryEditorController(
        document: widget.document,
        config: widget.config,
      ));

  @override
  void initState() {
    super.initState();
    _listen(_controller);
  }

  @override
  void didUpdateWidget(StoryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final owned = _ownedController;
    if (widget.controller != null && owned != null) {
      owned.dispose();
      _ownedController = null;
    }
    if (oldWidget.renderers == null && widget.renderers != null) {
      _ownedRenderers?.dispose();
      _ownedRenderers = null;
    }
    if (oldWidget.tools == null && widget.tools != null) {
      _ownedTools?.dispose();
      _ownedTools = null;
    }
    _listen(_controller);
  }

  @override
  void dispose() {
    _listening?.removeListener(_onControllerChanged);
    _ownedController?.dispose();
    _ownedRenderers?.dispose();
    _ownedTools?.dispose();
    super.dispose();
  }

  void _listen(StoryEditorController controller) {
    if (identical(_listening, controller)) return;
    _listening?.removeListener(_onControllerChanged);
    controller.addListener(_onControllerChanged);
    _listening = controller;
    _lastDocument = controller.document;
  }

  void _onControllerChanged() {
    final document = _controller.document;
    if (identical(document, _lastDocument)) return;
    _lastDocument = document;
    widget.onChanged?.call(document);
  }

  void _withController(void Function(StoryEditorController controller) action) {
    final controller = _controller;
    if (controller.editingTextId != null || controller.isDisposed) return;
    action(controller);
  }

  /// Runs editor shortcuts, except while a text field has focus: typing,
  /// deleting, and moving the caret must reach the field, not the editor.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_isTyping()) return KeyEventResult.ignored;
    for (final MapEntry(key: activator, value: callback)
        in _shortcuts.entries) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        callback();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  bool _isTyping() {
    if (_controller.editingTextId != null) return true;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    final config = _controller.config;
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.delete): () =>
          _withController((c) => c.deleteSelection()),
      const SingleActivator(LogicalKeyboardKey.backspace): () =>
          _withController((c) => c.deleteSelection()),
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          _withController((c) => c.clearSelection()),
      const SingleActivator(LogicalKeyboardKey.bracketRight): () =>
          _withController((c) => c.bringForward()),
      const SingleActivator(LogicalKeyboardKey.bracketLeft): () =>
          _withController((c) => c.sendBackward()),
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
          _withController((c) => c.redo()),
    };
    for (final meta in [false, true]) {
      shortcuts.addAll({
        SingleActivator(LogicalKeyboardKey.keyZ, control: !meta, meta: meta):
            () => _withController((c) => c.undo()),
        SingleActivator(LogicalKeyboardKey.keyZ,
            control: !meta,
            meta: meta,
            shift: true): () => _withController((c) => c.redo()),
        SingleActivator(LogicalKeyboardKey.keyD, control: !meta, meta: meta):
            () => _withController((c) => c.duplicateSelection()),
        SingleActivator(LogicalKeyboardKey.keyA, control: !meta, meta: meta):
            () => _withController((c) => c.selectAll()),
      });
    }
    for (final large in [false, true]) {
      shortcuts.addAll({
        SingleActivator(LogicalKeyboardKey.arrowLeft, shift: large): () =>
            _withController((c) => c.nudgeSelection(-1, 0, large: large)),
        SingleActivator(LogicalKeyboardKey.arrowRight, shift: large): () =>
            _withController((c) => c.nudgeSelection(1, 0, large: large)),
        SingleActivator(LogicalKeyboardKey.arrowUp, shift: large): () =>
            _withController((c) => c.nudgeSelection(0, -1, large: large)),
        SingleActivator(LogicalKeyboardKey.arrowDown, shift: large): () =>
            _withController((c) => c.nudgeSelection(0, 1, large: large)),
      });
    }
    return config.keyboardShortcuts ? shortcuts : const {};
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final renderers = widget.renderers ??
        (_ownedRenderers ??= StoryRendererRegistry.withDefaults());
    final tools = widget.tools ??
        (_ownedTools ??= StoryEditorToolRegistry(defaultStoryEditorTools(
          imagePicker: widget.imagePicker,
          videoPicker: widget.videoPicker,
          stickerPicker: widget.stickerPicker,
        )));

    final parts = StoryEditorParts(
      controller: controller,
      toolbar: widget.toolbarBuilder?.call(context, controller) ??
          StoryEditorToolbar(controller: controller, tools: tools),
      canvas: StoryEditorCanvas(
        controller: controller,
        tools: tools,
        backgroundColor: const Color(0x00000000),
        renderers: renderers,
        renderOptions: widget.renderOptions,
      ),
      layers: widget.layersBuilder?.call(context, controller) ??
          StoryLayersPanel(controller: controller),
      properties: widget.propertiesBuilder?.call(context, controller) ??
          StoryPropertiesPanel(controller: controller),
      timeline: widget.timelineBuilder?.call(context, controller) ??
          StoryTimelinePanel(controller: controller, renderers: renderers),
    );

    return DefaultTextStyle.merge(
      style: const TextStyle(color: StoryEditorColors.text, fontSize: 13),
      child: Focus(
        onKeyEvent: _handleKey,
        child: Focus(
          autofocus: true,
          child: widget.layoutBuilder?.call(context, parts) ??
              StoryEditorDefaultLayout(parts: parts),
        ),
      ),
    );
  }
}

/// The default editor arrangement.
///
/// Wide layouts (at least [wideBreakpoint] pixels) show the canvas with a
/// side panel of layers and properties. Narrow layouts (phones) give the
/// canvas most of the screen and put properties and layers in a collapsible
/// sheet below it, which opens when something is selected and closes when
/// the selection is cleared. The timeline is at the bottom, except on narrow
/// layouts while the sheet is open.
class StoryEditorDefaultLayout extends StatefulWidget {
  /// Creates the default layout.
  const StoryEditorDefaultLayout({
    required this.parts,
    this.wideBreakpoint = 720,
    this.sidePanelWidth = 320,
    this.timelineHeight = 176,
    this.compactTimelineHeight = 132,
    super.key,
  });

  /// The pieces to arrange.
  final StoryEditorParts parts;

  /// Minimum width for the side-panel layout.
  final double wideBreakpoint;

  /// Width of the side panel in wide layouts.
  final double sidePanelWidth;

  /// Height of the timeline in wide layouts.
  final double timelineHeight;

  /// Height of the timeline in narrow layouts.
  final double compactTimelineHeight;

  @override
  State<StoryEditorDefaultLayout> createState() =>
      _StoryEditorDefaultLayoutState();
}

/// Which part the narrow layout's sheet shows.
enum _SheetTab { edit, layers }

class _StoryEditorDefaultLayoutState extends State<StoryEditorDefaultLayout> {
  static const double _gap = 10;

  _SheetTab _tab = _SheetTab.edit;
  bool _open = false;
  bool _hadSelection = false;
  bool _wasDrawing = false;
  StoryEditorController? _listening;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(StoryEditorDefaultLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
  }

  @override
  void dispose() {
    _listening?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _listen() {
    final controller = widget.parts.controller;
    if (identical(_listening, controller)) return;
    _listening?.removeListener(_onControllerChanged);
    controller.addListener(_onControllerChanged);
    _listening = controller;
    _hadSelection = controller.editableSelection.isNotEmpty;
    _wasDrawing = controller.activeToolId == StoryDrawTool.toolId;
    _open = _hadSelection || _wasDrawing;
  }

  /// Opens the sheet on Edit when editing starts; closes it again when the
  /// selection is cleared, unless the user is browsing layers.
  void _onControllerChanged() {
    final controller = widget.parts.controller;
    final hasSelection = controller.editableSelection.isNotEmpty;
    final drawing = controller.activeToolId == StoryDrawTool.toolId;
    final starts =
        (hasSelection && !_hadSelection) || (drawing && !_wasDrawing);
    final ends = !hasSelection && !drawing && (_hadSelection || _wasDrawing);
    _hadSelection = hasSelection;
    _wasDrawing = drawing;
    if (starts) {
      setState(() {
        _open = true;
        _tab = _SheetTab.edit;
      });
    } else if (ends && _tab == _SheetTab.edit && _open) {
      setState(() => _open = false);
    }
  }

  void _select(_SheetTab tab) => setState(() {
        if (_open && _tab == tab) {
          _open = false;
        } else {
          _open = true;
          _tab = tab;
        }
      });

  @override
  Widget build(BuildContext context) {
    final parts = widget.parts;
    return ColoredBox(
      color: StoryEditorColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= widget.wideBreakpoint;
          final canvas = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: const _DotGridPainter(),
              child: parts.canvas,
            ),
          );
          final sheetHeight =
              (constraints.maxHeight * 0.34).clamp(150.0, 280.0);
          return Padding(
            padding: const EdgeInsets.all(_gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: parts.toolbar),
                const SizedBox(height: _gap),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: canvas),
                            const SizedBox(width: _gap),
                            SizedBox(
                              width: widget.sidePanelWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 2, child: parts.layers),
                                  const SizedBox(height: _gap),
                                  Expanded(flex: 3, child: parts.properties),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: canvas),
                            const SizedBox(height: _gap),
                            _SheetTabs(
                              tab: _tab,
                              open: _open,
                              onSelected: _select,
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _open
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: SizedBox(
                                        height: sheetHeight,
                                        child: _tab == _SheetTab.edit
                                            ? parts.properties
                                            : parts.layers,
                                      ),
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                          ],
                        ),
                ),
                // On phones the open sheet takes the timeline's place, so the
                // canvas keeps its room while an element is being edited.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: wide || !_open
                      ? Padding(
                          padding: const EdgeInsets.only(top: _gap),
                          child: SizedBox(
                            height: wide
                                ? widget.timelineHeight
                                : widget.compactTimelineHeight,
                            child: parts.timeline,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The Edit and Layers switches above the narrow layout's sheet. Tapping the
/// open tab collapses the sheet.
class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.tab,
    required this.open,
    required this.onSelected,
  });

  final _SheetTab tab;
  final bool open;
  final ValueChanged<_SheetTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final editOpen = open && tab == _SheetTab.edit;
    final layersOpen = open && tab == _SheetTab.layers;
    return Row(
      children: [
        StoryEditorButtonGroup(children: [
          StoryEditorButton(
            label: editOpen ? 'Hide properties' : 'Show properties',
            icon: StoryEditorIcons.sparkle,
            glyph: 'Edit',
            selected: editOpen,
            onPressed: () => onSelected(_SheetTab.edit),
          ),
          StoryEditorButton(
            label: layersOpen ? 'Hide layers' : 'Show layers',
            icon: StoryEditorIcons.layers,
            glyph: 'Layers',
            selected: layersOpen,
            onPressed: () => onSelected(_SheetTab.layers),
          ),
        ]),
        const Spacer(),
        StoryEditorButton(
          label: open ? 'Collapse panel' : 'Expand panel',
          icon:
              open ? StoryEditorIcons.chevronDown : StoryEditorIcons.chevronUp,
          onPressed: () => onSelected(tab),
        ),
      ],
    );
  }
}

/// A subtle dotted workspace behind the canvas.
final class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF111118));
    final dot = Paint()..color = const Color(0xFF262631);
    const spacing = 22.0;
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}
