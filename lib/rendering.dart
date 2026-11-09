/// The shared rendering system: renderer contracts, the renderer registry,
/// built-in renderers, and widgets that draw story items on a scaled canvas.
///
/// Used by the viewer, the editor, and export, and independent of playback.
library;

export 'composition.dart';
export 'src/rendering/contracts/story_element_renderer.dart';
export 'src/rendering/conversions.dart';
export 'src/rendering/media/story_image_resolver.dart';
export 'src/rendering/options/story_render_options.dart';
export 'src/rendering/registry/story_renderer_registry.dart';
export 'src/rendering/renderers/builtin_renderers.dart'
    hide defaultStoryRenderers;
export 'src/rendering/widgets/story_item_view.dart';
