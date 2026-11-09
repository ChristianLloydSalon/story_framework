import 'package:meta/meta.dart';

import '../../core/errors/story_exceptions.dart';
import '../../core/errors/validation_issue.dart';
import '../../core/models/story_source.dart';
import '../document/story_background.dart';
import '../document/story_document.dart';
import '../elements/element_styles.dart';
import '../elements/interactions.dart';
import '../elements/story_element.dart';
import '../items/item_timing.dart';
import '../items/story_item.dart';

/// An additional, application-specific validation rule.
abstract interface class StoryValidationRule {
  /// Returns every issue this rule finds in [document].
  Iterable<StoryValidationIssue> validate(StoryDocument document);
}

/// The outcome of validating a document.
@immutable
final class StoryValidationResult {
  /// Creates a result from [issues].
  StoryValidationResult(List<StoryValidationIssue> issues)
      : issues = List.unmodifiable(issues);

  /// Every issue found, errors and warnings.
  final List<StoryValidationIssue> issues;

  /// Error-level issues.
  Iterable<StoryValidationIssue> get errors =>
      issues.where((issue) => issue.isError);

  /// Warning-level issues.
  Iterable<StoryValidationIssue> get warnings =>
      issues.where((issue) => !issue.isError);

  /// Whether the document has no errors (warnings are allowed).
  bool get isValid => errors.isEmpty;

  /// Throws an [InvalidCompositionException] unless [isValid].
  void throwIfInvalid() {
    if (!isValid) throw InvalidCompositionException(issues);
  }

  @override
  String toString() => 'StoryValidationResult(${errors.length} errors, '
      '${warnings.length} warnings)';
}

/// Stable codes reported by [StoryDocumentValidator].
abstract final class StoryValidationCodes {
  /// An id is empty.
  static const String emptyId = 'empty_id';

  /// Two siblings share an id.
  static const String duplicateId = 'duplicate_id';

  /// A numeric value is outside its allowed range.
  static const String outOfRange = 'out_of_range';

  /// A reference points at a missing asset or element.
  static const String missingReference = 'missing_reference';

  /// A source cannot be serialized.
  static const String notSerializable = 'not_serializable';

  /// Timestamps or time ranges are in the wrong order.
  static const String invalidTimeRange = 'invalid_time_range';

  /// A container has no content.
  static const String empty = 'empty';
}

/// Checks a [StoryDocument] for structural problems.
///
/// Built-in checks cover ids, numeric ranges, time ranges, and references.
/// Pass [rules] to add application-specific checks.
///
/// Element ids must be unique within their item; group and item ids must be
/// unique within the document.
final class StoryDocumentValidator {
  /// Creates a validator with optional extra [rules].
  const StoryDocumentValidator({this.rules = const []});

  /// Application-specific rules run after the built-in checks.
  final List<StoryValidationRule> rules;

  /// Validates [document].
  StoryValidationResult validate(StoryDocument document) {
    final context = _Context(document);
    context.run();
    for (final rule in rules) {
      context.issues.addAll(rule.validate(document));
    }
    return StoryValidationResult(context.issues);
  }

  /// Validates [document] and throws an [InvalidCompositionException] if it
  /// has errors.
  void validateOrThrow(StoryDocument document) =>
      validate(document).throwIfInvalid();
}

final class _Context {
  _Context(this.document);

  final StoryDocument document;
  final List<StoryValidationIssue> issues = [];

  void error(String code, String message, String path) =>
      issues.add(StoryValidationIssue.error(code, message, path: path));

  void warning(String code, String message, String path) =>
      issues.add(StoryValidationIssue.warning(code, message, path: path));

  void run() {
    _id(document.id, 'id');
    _canvas();
    _assets();

    if (document.groups.isEmpty) {
      warning(StoryValidationCodes.empty, 'Document has no groups', 'groups');
    }

    final groupIds = <String>{};
    final itemIds = <String>{};
    for (final (g, group) in document.groups.indexed) {
      final path = 'groups[$g]';
      _id(group.id, '$path.id');
      if (!groupIds.add(group.id)) {
        error(StoryValidationCodes.duplicateId,
            'Duplicate group id "${group.id}"', '$path.id');
      }
      final created = group.createdAt;
      final expires = group.expiresAt;
      if (created != null && expires != null && !expires.isAfter(created)) {
        error(StoryValidationCodes.invalidTimeRange,
            'Group expires before it is created', '$path.expiresAt');
      }
      if (group.items.isEmpty) {
        warning(
            StoryValidationCodes.empty, 'Group has no items', '$path.items');
      }
      for (final (i, item) in group.items.indexed) {
        final itemPath = '$path.items[$i]';
        _id(item.id, '$itemPath.id');
        if (!itemIds.add(item.id)) {
          error(StoryValidationCodes.duplicateId,
              'Duplicate item id "${item.id}"', '$itemPath.id');
        }
        _item(item, itemPath);
      }
    }
  }

  void _canvas() {
    final canvas = document.canvas;
    if (!(canvas.width.isFinite && canvas.width > 0)) {
      error(StoryValidationCodes.outOfRange,
          'Canvas width must be a positive number', 'canvas.width');
    }
    if (!(canvas.height.isFinite && canvas.height > 0)) {
      error(StoryValidationCodes.outOfRange,
          'Canvas height must be a positive number', 'canvas.height');
    }
    if (!canvas.safeArea.isValid) {
      error(StoryValidationCodes.outOfRange,
          'Safe area insets must be non-negative', 'canvas.safeArea');
    }
    _background(canvas.background, 'canvas.background');
  }

  void _assets() {
    final ids = <String>{};
    for (final (i, asset) in document.assets.indexed) {
      final path = 'assets[$i]';
      _id(asset.id, '$path.id');
      if (!ids.add(asset.id)) {
        error(StoryValidationCodes.duplicateId,
            'Duplicate asset id "${asset.id}"', '$path.id');
      }
      _source(asset.source, '$path.source');
    }
  }

  void _item(StoryItem item, String path) {
    final background = item.background;
    if (background != null) _background(background, '$path.background');

    final elementIds = <String>{};
    for (final (e, element) in item.elements.indexed) {
      final elementPath = '$path.elements[$e]';
      _id(element.id, '$elementPath.id');
      if (!elementIds.add(element.id)) {
        error(StoryValidationCodes.duplicateId,
            'Duplicate element id "${element.id}" in item', '$elementPath.id');
      }
      _element(element, elementPath);
    }

    switch (item.duration) {
      case FixedItemDuration(:final duration) when duration <= Duration.zero:
        error(StoryValidationCodes.outOfRange,
            'Fixed duration must be positive', '$path.duration');
      case MediaItemDuration(:final elementId, :final maxDuration):
        if (elementId != null) {
          final target = item.elementById(elementId);
          if (target == null || !target.isTimeBased) {
            error(
                StoryValidationCodes.missingReference,
                'Media duration references "$elementId", which is not a video '
                    'or audio element in this item',
                '$path.duration.elementId');
          }
        } else if (item.timeBasedElements.isEmpty) {
          error(
              StoryValidationCodes.missingReference,
              'Media duration needs a video or audio element',
              '$path.duration');
        }
        if (maxDuration != null && maxDuration <= Duration.zero) {
          error(
              StoryValidationCodes.outOfRange,
              'Maximum duration must be positive',
              '$path.duration.maxDuration');
        }
      default:
        break;
    }

    final transition = item.transition;
    if (transition != null && transition.duration < Duration.zero) {
      error(
          StoryValidationCodes.outOfRange,
          'Transition duration cannot be negative',
          '$path.transition.duration');
    }
  }

  void _element(StoryElement element, String path) {
    final transform = element.transform;
    if (!transform.position.isFinite) {
      error(StoryValidationCodes.outOfRange, 'Position must be finite',
          '$path.transform.position');
    }
    if (!transform.size.isFinite ||
        transform.size.width < 0 ||
        transform.size.height < 0) {
      error(StoryValidationCodes.outOfRange,
          'Size must be finite and non-negative', '$path.transform.size');
    }
    if (!(transform.scale.isFinite && transform.scale > 0)) {
      error(StoryValidationCodes.outOfRange, 'Scale must be positive',
          '$path.transform.scale');
    }
    if (!transform.rotation.isFinite) {
      error(StoryValidationCodes.outOfRange, 'Rotation must be finite',
          '$path.transform.rotation');
    }
    _unitInterval(element.opacity, '$path.opacity', 'Opacity');

    switch (element) {
      case ImageElement(:final source):
        _source(source, '$path.source');
      case VideoElement(:final poster):
        _timedMedia(element, path);
        if (poster != null) _source(poster, '$path.poster');
      case AudioElement():
        _timedMedia(element, path);
      case TextElement(:final text, :final style):
        if (text.trim().isEmpty) {
          warning(StoryValidationCodes.empty, 'Text is empty', '$path.text');
        }
        if (!(style.fontSize.isFinite && style.fontSize > 0)) {
          error(StoryValidationCodes.outOfRange, 'Font size must be positive',
              '$path.style.fontSize');
        }
        if (style.fontWeight < 100 || style.fontWeight > 900) {
          error(
              StoryValidationCodes.outOfRange,
              'Font weight must be between 100 and 900',
              '$path.style.fontWeight');
        }
      case StickerElement(:final sticker):
        if (sticker is ImageSticker) {
          _source(sticker.source, '$path.sticker.source');
        }
      case DrawingElement(:final strokes):
        for (final (s, stroke) in strokes.indexed) {
          final strokePath = '$path.strokes[$s]';
          if (stroke.points.isEmpty) {
            warning(StoryValidationCodes.empty, 'Stroke has no points',
                '$strokePath.points');
          }
          if (!(stroke.width.isFinite && stroke.width > 0)) {
            error(StoryValidationCodes.outOfRange,
                'Stroke width must be positive', '$strokePath.width');
          }
          _unitInterval(stroke.opacity, '$strokePath.opacity', 'Opacity');
        }
      case ShapeElement(:final cornerRadius):
        if (!(cornerRadius.isFinite && cornerRadius >= 0)) {
          error(StoryValidationCodes.outOfRange,
              'Corner radius must be non-negative', '$path.cornerRadius');
        }
      case InteractiveElement(:final interaction):
        _interaction(interaction, '$path.interaction');
      case WidgetElement() || CustomElement() || UnknownElement():
        break;
    }
  }

  void _interaction(StoryInteraction interaction, String path) {
    void choices(List<StoryChoice> list) {
      if (list.length < 2) {
        error(StoryValidationCodes.outOfRange, 'At least two choices needed',
            '$path.choices');
      }
      final ids = <String>{};
      for (final (i, choice) in list.indexed) {
        _id(choice.id, '$path.choices[$i].id');
        if (!ids.add(choice.id)) {
          error(StoryValidationCodes.duplicateId,
              'Duplicate choice id "${choice.id}"', '$path.choices[$i].id');
        }
        if (choice.label.trim().isEmpty) {
          warning(StoryValidationCodes.empty, 'Choice label is empty',
              '$path.choices[$i].label');
        }
      }
    }

    void text(String value, String field) {
      if (value.trim().isEmpty) {
        warning(StoryValidationCodes.empty, 'Text is empty', '$path.$field');
      }
    }

    switch (interaction) {
      case StoryPoll(:final question, choices: final options):
        text(question, 'question');
        choices(options);
      case StoryQuiz(
          :final question,
          choices: final options,
          :final correctChoiceId,
        ):
        text(question, 'question');
        choices(options);
        if (!options.any((choice) => choice.id == correctChoiceId)) {
          error(
              StoryValidationCodes.missingReference,
              'Correct choice "$correctChoiceId" is not one of the choices',
              '$path.correctChoiceId');
        }
      case StoryQuestion(:final prompt):
        text(prompt, 'prompt');
      case StorySlider(:final question):
        text(question, 'question');
      case StoryCountdown(:final title):
        text(title, 'title');
      case StoryLink(:final url, :final label):
        text(label, 'label');
        if (!(url.isScheme('http') || url.isScheme('https'))) {
          error(StoryValidationCodes.outOfRange, 'Links must use http or https',
              '$path.url');
        }
      case StoryProductTag(:final productId, :final name):
        _id(productId, '$path.productId');
        text(name, 'name');
      case StoryCustomInteraction(:final type):
        _id(type, '$path.type');
    }
  }

  void _timedMedia(TimedMediaElement element, String path) {
    _source(element.source, '$path.source');
    _unitInterval(element.volume, '$path.volume', 'Volume');
    if (element.trimStart < Duration.zero) {
      error(StoryValidationCodes.outOfRange, 'Trim start cannot be negative',
          '$path.trimStart');
    }
    final trimEnd = element.trimEnd;
    if (trimEnd != null && trimEnd <= element.trimStart) {
      error(StoryValidationCodes.invalidTimeRange,
          'Trim end must be after trim start', '$path.trimEnd');
    }
  }

  void _background(StoryBackground background, String path) {
    switch (background) {
      case StoryGradientBackground(:final colors, :final stops):
        if (colors.length < 2) {
          error(StoryValidationCodes.outOfRange,
              'A gradient needs at least two colors', '$path.colors');
        }
        if (stops != null &&
            (stops.length != colors.length ||
                stops.any((stop) => stop < 0 || stop > 1))) {
          error(
              StoryValidationCodes.outOfRange,
              'Gradient stops must match the colors and lie between 0 and 1',
              '$path.stops');
        }
      case StoryMediaBackground(:final source):
        _source(source, '$path.source');
      case StoryColorBackground():
        break;
    }
  }

  void _source(StorySource source, String path) {
    switch (source) {
      case ReferenceStorySource(:final assetId):
        if (document.assetById(assetId) == null) {
          error(StoryValidationCodes.missingReference,
              'Asset "$assetId" does not exist', '$path.assetId');
        }
      case NetworkStorySource(:final url):
        if (!url.hasScheme ||
            !(url.isScheme('http') || url.isScheme('https'))) {
          error(StoryValidationCodes.outOfRange,
              'Network sources must use http or https', '$path.url');
        }
      case StreamStorySource():
        warning(StoryValidationCodes.notSerializable,
            'Stream sources are runtime-only and cannot be saved', path);
      case FileStorySource() ||
            AssetStorySource() ||
            MemoryStorySource() ||
            CustomStorySource():
        break;
    }
  }

  void _unitInterval(double value, String path, String label) {
    if (!(value >= 0 && value <= 1)) {
      error(StoryValidationCodes.outOfRange, '$label must be between 0 and 1',
          path);
    }
  }

  void _id(String id, String path) {
    if (id.trim().isEmpty) {
      error(StoryValidationCodes.emptyId, 'Id must not be empty', path);
    }
  }
}
