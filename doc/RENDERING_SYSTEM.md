# Rendering System

`package:story_framework/rendering.dart` turns composition models into
widgets. The viewer, the editor, and export all use it, and it does not depend
on playback.

```dart
final registry = StoryRendererRegistry.withDefaults([
  StoryWidgetElementRenderer({
    'poll': (context, element, _) => PollWidget(element.data),
  }),
  StoryCustomElementRenderer(
    customType: 'map',
    builder: (context, element, _) => MapPreview(element.data),
  ),
]);

StoryItemView(
  document: document,
  item: document.groups.first.items.first,
  registry: registry, // you own and dispose it
  options: StoryRenderOptions(
    imageResolver: DefaultStoryImageResolver(
      headersFor: (url) => {'Authorization': 'Bearer $token'},
    ),
    loadingBuilder: (context, element) => const Shimmer(),
    errorBuilder: (context, element, error) => const BrokenImage(),
    onError: (element, error, stack) => log(error),
  ),
);
```

## Layout

`StoryItemView` lays elements out in **canvas units** inside a canvas-sized
box, then scales that box to the available space with
`canvas.scalingBehavior` (`contain`, `cover`, or `fill`). Text sizes, stroke
widths, and positions all scale together, so an item looks the same on every
screen and in exports. With unbounded constraints, the view uses the canvas
aspect ratio.

For each visible element, in `zIndex` order, `StoryElementView`:

1. positions a box of `transform.size` centered on `transform.position`;
2. applies rotation, uniform scale, and flips around the center;
3. applies `opacity`;
4. adds the `semanticLabel` (if any) as the element's accessible label;
5. asks the renderer to fill the box with content.

Renderers only draw content. They never position or transform themselves.

## Renderer contract

```dart
abstract class StoryElementRenderer<E extends StoryElement> {
  String get id;                       // unique in a registry
  bool supports(StoryElement element); // default: element is E
  Widget buildElement(BuildContext, E element, StoryRenderContext);
  void dispose();                      // shared resources only
}
```

- **Shared and stateless.** One renderer builds many elements. Per-element
  resources (image streams, players, animation controllers) belong in the
  `State` of the widget it returns, so Flutter creates and disposes them with
  the element's subtree. Elements are keyed by id, so that state survives
  rebuilds.
- **Synchronous build.** Async content shows
  `StoryElementLoading(renderContext: ...)` until ready and
  `StoryElementError(renderContext: ..., error: ...)` on failure.
  `StoryImageContent` packages both for images and can be reused by custom
  renderers.
- **Ownership.** The registry owns its renderers and calls `dispose()` when a
  renderer is replaced or the registry is disposed.

`StoryRenderContext` provides the element, item, document, `mode` (`viewer`,
`editor`, or `export`), options, `resolveSource` (asset references), and
`imageProviderFor`.

## Registry

| Operation | Behavior |
|---|---|
| `register` | Adds a renderer; a duplicate id throws `ConfigurationException` |
| `replace` | Swaps the renderer with the same id, keeping its priority; disposes the old one; a missing id throws |
| `unregister` | Removes and returns it; the caller now owns it |
| `rendererFor` | Newest supporting renderer wins, so specialized renderers can take over some elements from a built-in |
| `requireRendererFor` | Throws `RendererNotRegisteredException` |
| `dispose` | Disposes every renderer |

The registry is a `ChangeNotifier`, so views rebuild when renderers change.

## Built-in renderers

| Id | Elements | Notes |
|---|---|---|
| `image` | `ImageElement` | Fit, loading and error states |
| `video` | `VideoElement` | Frames of the engine's controller, poster, optional previews (see [MEDIA_SYSTEM.md](MEDIA_SYSTEM.md)) |
| `text` | `TextElement` | Style, background, padding, shadows, outline stroke |
| `sticker` | `StickerElement` | Emoji and image stickers; provider stickers via `customBuilders` |
| `shape` | `ShapeElement` | Rectangle (rounded), ellipse, line, triangle |
| `drawing` | `DrawingElement` | Vector strokes; the eraser clears only that drawing's own earlier strokes |
| `audio` | `AudioElement` | No visual output |

`WidgetElement`s need a `StoryWidgetElementRenderer` with builders keyed by
`widgetType`. `CustomElement`s need a `StoryCustomElementRenderer`, or a
`StoryElementRenderer` subclass, for their `customType`.

## Unsupported content and errors

- Elements without a renderer, including `UnknownElement`s from newer
  documents, render `unsupportedBuilder` (default: nothing). They are reported
  once through `onError` as a `RendererNotRegisteredException`.
- Content failures (an unloadable source, a missing asset, a decode error)
  render `errorBuilder` and are reported once.
- `onError` defaults to `FlutterError.reportError`, so failures are never
  silently swallowed. Reports are delivered after the frame, so callbacks may
  call `setState`.
- Media backgrounds have no element; their failures go to Flutter's standard
  error reporting.

## Images

`DefaultStoryImageResolver` maps network, file, asset, and memory sources to
Flutter image providers. It adds HTTP headers from `headersFor` (credentials
stay in the app, never in the document) and supports `CustomStorySource` types
through `customResolvers`. File images use a conditional import, so the
package still compiles for the web, where file sources are unsupported.
Implement `StoryImageResolver` to add caching or a different loading strategy.

## Text scaling

Text is sized in canvas units, so it already scales with the canvas.
`StoryRenderOptions.textScaler` defaults to `TextScaler.noScaling` so platform
text scaling doesn't push text out of its designed box. Pass
`MediaQuery.textScalerOf(context)` to apply the user's setting.
