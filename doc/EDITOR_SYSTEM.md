# Editor System

`package:story_framework/editor.dart` creates and edits `StoryDocument`s,
the same documents the viewer plays. It is independent of playback, and every
layer can be used on its own:

| Layer | Use it for |
|---|---|
| `StoryEditor` | A complete editor UI, with every part replaceable |
| `StoryEditorCanvas` | Just the editing surface, inside your own UI |
| `StoryEditorController` | Headless editing: commands, selection, history |
| `StoryEditCommand` + `document_edits` | Pure, testable document transformations |

```dart
StoryEditor(
  document: draft,                       // or a blank story
  onChanged: (document) => saveDraft(document),
  imagePicker: () async => pickImageSource(),  // adds the image tool
)
```

## Controller

`StoryEditorController` holds the document, the **current item** (the one on
the canvas), the selection, the active tool, and the history.

- **Elements:** `addElement`, `updateElement(s)`, `deleteSelection`,
  `duplicateSelection`, `moveSelection`, `nudgeSelection`, `flipSelection`,
  `renameElement`, `toggleVisible`, `toggleLocked`, text editing
  (`beginTextEditing`, `setText`).
- **Layers:** `bringForward`, `sendBackward`, `bringToFront`, `sendToBack`,
  `reorderLayer`. Reordering renumbers z-indexes to match list order, so
  paint order is always deterministic.
- **Alignment:** `alignSelection` (to each other, or to the canvas for a
  single element) and `distributeSelection` (three or more).
- **Selection:** `select`, `toggleSelection`, `selectAll`, `selectInRect`,
  `clearSelection`. Ids that no longer exist are dropped automatically.
- **Locked elements** are skipped by canvas hit testing and by every
  selection operation (move, transform, delete, duplicate, align).

## Commands and history

Every change is a `StoryEditCommand` passed to `execute`, which records one
undo step labeled with the command (shown as "Undo Move" and similar).

- **Pure commands.** `apply(document)` returns a new document. Documents share
  every unchanged group, item, and element, so an undo step stores only the
  changed path, not a copy of the whole story.
- **Transactions.** `beginTransaction` / `commitTransaction` (or
  `runTransaction`) merge many edits into one step: a drag, a typed word, a
  freehand stroke. Transactions nest. `cancelTransaction` reverts, and
  `runTransaction` reverts automatically if its callback throws.
- **Selection** is restored with undo and redo.
- **Limits.** `StoryEditorConfig.historyLimit` (default 100) bounds memory;
  the oldest steps are dropped first. A new edit clears the redo stack.
- **Validation.** `StoryEditorConfig.validation` is `report` by default
  (`lastValidation` holds the result after each edit). `reject` refuses
  edits that would make the story invalid, and `none` skips validation.
- **Custom edits:** implement `StoryEditCommand`, or use
  `StoryDocumentEdit('Label', (doc) => ...)`.

The `StoryDocumentEditing` and `StoryItemEditing` extensions (`updateItem`,
`insertItem`, `moveItem`, `insertElement`, `replaceElements`,
`reorderLayers`, ...) are the building blocks for commands, and are usable
anywhere.

## Timeline

Story items are edited through the controller and the default
`StoryTimelinePanel`:

| Operation | Controller |
|---|---|
| Add / duplicate / delete / reorder items | `addItem`, `duplicateItem`, `removeItem`, `moveItem` |
| Display duration | `setItemDuration` (`null` = playback default) |
| Entrance transition | `setItemTransition` (`null` = viewer default) |
| Background | `setItemBackground` |
| Video/audio trim | `setMediaTrim(start:, end:)` (`end: null` = play to the end) |
| Groups | `addGroup`, `renameGroup`, `removeGroup` |

Duplicated items and elements get fresh ids from the injected
`StoryIdGenerator` (`RandomStoryIdGenerator` by default,
`SequentialStoryIdGenerator` for tests).

## Canvas

`StoryEditorCanvas` renders the current item with the shared rendering
system (`StoryRenderMode.editor`; interactive stickers are inert previews)
and maps screen and canvas coordinates with `StoryViewportMapping`. All
edits work in canvas units, so they behave the same at any zoom or screen
size.

| Input | Effect |
|---|---|
| One finger / mouse | Sent to the active tool |
| Two-finger pinch or drag | Zoom and pan (view state only, never an undo step) |
| Mouse wheel | Zoom around the pointer |
| Corner handles | Scale (group scale for multi-selection) |
| Edge handles | Resize width or height in the element's own axes |
| Top handle | Rotate (snaps to 45° steps; group rotation for multi-selection) |

**Snapping.** Moving snaps edges and centers to the canvas, its safe area,
and other elements, within `snapThreshold` screen pixels, and shows
alignment guides (`controller.guides`).

## Tools

Tools receive canvas gestures in canvas coordinates through
`StoryToolContext`. They live in a `StoryEditorToolRegistry`; register your
own by subclassing `StoryEditorTool`.

| Id | Tool |
|---|---|
| `select` | Tap to select (Shift to add), drag to move, drag on empty space to select an area, double-tap text to edit it |
| `text` | Tap to add text and edit it inline |
| `image`, `video` | Tap to add media from an app-supplied picker (included only when a picker is given) |
| `sticker` | Tap to add a sticker from a picker, or a default emoji |
| `shape` | Drag out a shape, or tap for a default one |
| `draw` | Freehand strokes with `controller.brush` (stored as editable vector strokes) |
| `eraser` | Eraser strokes on the selected or topmost drawing |

The framework has no picker dependencies: `imagePicker`, `videoPicker`, and
`stickerPicker` are app callbacks that return a `StorySource` or
`StickerContent`.

## Default UI and customization

`StoryEditor` composes `StoryEditorToolbar`, `StoryEditorCanvas`,
`StoryLayersPanel`, `StoryPropertiesPanel`, and `StoryTimelinePanel` with
`StoryEditorDefaultLayout`: a side panel on wide screens, stacked panels on
narrow ones. Replace any part with `toolbarBuilder`, `layersBuilder`,
`propertiesBuilder`, or `timelineBuilder`, or rearrange everything with
`layoutBuilder` (it receives `StoryEditorParts`).

## Accessibility

Every canvas gesture has a non-gesture alternative:

- **Selection:** the layers panel selects, shows/hides, locks, and reorders
  elements.
- **Transforms:** the properties panel aligns, distributes, flips, rotates
  (15° steps), scales, changes opacity, and edits text style.
- **Keyboard:** Ctrl/Cmd+Z undo, Ctrl/Cmd+Shift+Z or Ctrl+Y redo,
  Ctrl/Cmd+D duplicate, Ctrl/Cmd+A select all, Delete/Backspace delete,
  arrows nudge (Shift for larger steps), `]`/`[` forward/backward, Escape
  deselect.
- **Buttons** have descriptive screen-reader labels, are keyboard-focusable,
  and activate with Enter or Space. Only real toggles (tools, bold) expose a
  selected state.

## Not included yet

- Advanced video editing (clip splitting, multi-track timelines, keyframes)
  is outside the first editor's scope.
- Free-form text formatting within a single text element (mixed styles) is
  not supported; each text element has one style.
