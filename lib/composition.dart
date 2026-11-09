/// The shared story composition model: documents, groups, items, elements,
/// serialization, and validation.
///
/// This library does not import Flutter, so it can be used in background
/// isolates (for example to decode large documents) and widget-free tests.
library;

export 'src/composition/document/story_asset.dart';
export 'src/composition/document/story_background.dart';
export 'src/composition/document/story_canvas_configuration.dart';
export 'src/composition/document/story_document.dart';
export 'src/composition/elements/element_styles.dart';
export 'src/composition/elements/interactions.dart';
export 'src/composition/elements/story_element.dart';
export 'src/composition/elements/story_transform.dart';
export 'src/composition/groups/story_group.dart';
export 'src/composition/items/item_timing.dart';
export 'src/composition/items/story_item.dart';
export 'src/composition/serialization/story_document_codec.dart';
export 'src/composition/validation/story_document_validator.dart';
export 'src/core/contracts/story_playback_hold.dart';
export 'src/core/enums/story_enums.dart';
export 'src/core/errors/story_exceptions.dart';
export 'src/core/errors/validation_issue.dart';
export 'src/core/models/geometry.dart';
export 'src/core/models/playback_state.dart';
export 'src/core/models/story_color.dart';
export 'src/core/models/story_source.dart';
export 'src/core/utilities/json.dart'
    show JsonMap, deepEquals, deepHash, isJsonCompatible;
