import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../core/enums/story_enums.dart';
import '../../core/errors/story_exceptions.dart';
import '../../core/models/geometry.dart';
import '../../core/models/story_color.dart';
import '../../core/models/story_source.dart';
import '../../core/utilities/json.dart';
import '../document/story_asset.dart';
import '../document/story_background.dart';
import '../document/story_canvas_configuration.dart';
import '../document/story_document.dart';
import '../elements/element_styles.dart';
import '../elements/interactions.dart';
import '../elements/story_element.dart';
import '../elements/story_transform.dart';
import '../groups/story_group.dart';
import '../items/item_timing.dart';
import '../items/story_item.dart';
import 'json_reader.dart';

/// What the codec does with an element type it does not recognize.
enum UnknownElementPolicy {
  /// Keep it as an [UnknownElement] so it survives re-encoding.
  preserve,

  /// Drop it from the decoded document.
  skip,

  /// Throw a [SerializationException].
  error,
}

/// Upgrades serialized documents from one schema version to the next.
///
/// Migrations operate on raw JSON so they can handle shapes the current model
/// no longer understands.
abstract interface class StoryDocumentMigration {
  /// The schema version this migration reads; it produces `fromVersion + 1`.
  int get fromVersion;

  /// Returns the document JSON upgraded to `fromVersion + 1`.
  JsonMap migrate(JsonMap json);
}

/// Converts [StoryDocument]s to and from a versioned JSON representation.
///
/// The format stores only descriptions of content. Live controllers, widgets,
/// and runtime resource handles are never serialized; a [StreamStorySource]
/// cannot be encoded and throws a [SerializationException].
///
/// ```dart
/// const codec = StoryDocumentCodec();
/// final json = codec.encodeToString(document);
/// final restored = codec.decodeFromString(json);
/// ```
final class StoryDocumentCodec {
  /// Creates a codec.
  ///
  /// [migrations] upgrade documents written with older schema versions.
  const StoryDocumentCodec({
    this.migrations = const [],
    this.unknownElementPolicy = UnknownElementPolicy.preserve,
  });

  /// The schema version this codec writes.
  static const int currentSchemaVersion = 1;

  /// Upgrades for documents with an older schema version.
  final List<StoryDocumentMigration> migrations;

  /// Handling of unrecognized element types.
  final UnknownElementPolicy unknownElementPolicy;

  /// Encodes [document] as a JSON-compatible map.
  JsonMap encode(StoryDocument document) => _Encoder().document(document);

  /// Encodes [document] as a JSON string.
  String encodeToString(StoryDocument document, {bool pretty = false}) {
    final json = encode(document);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(json)
        : jsonEncode(json);
  }

  /// Decodes a document from a JSON-compatible value.
  ///
  /// Throws a [SerializationException] when the input is malformed or was
  /// written by a newer schema version.
  StoryDocument decode(Object? json) {
    final root = JsonReader.root(json);
    final upgraded = _migrate(root);
    return _Decoder(unknownElementPolicy).document(upgraded);
  }

  /// Decodes a document from a JSON string.
  StoryDocument decodeFromString(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (error) {
      throw SerializationException('Invalid JSON', cause: error);
    }
    return decode(json);
  }

  JsonReader _migrate(JsonReader root) {
    var version = root.integer('schemaVersion');
    if (version > currentSchemaVersion) {
      root.fail(
        'schemaVersion',
        'Document schema $version is newer than the supported '
            '$currentSchemaVersion; upgrade story_framework to read it',
      );
    }
    if (version < 0) root.fail('schemaVersion', 'Invalid schema version');

    var json = root.json;
    while (version < currentSchemaVersion) {
      final from = version;
      final migration =
          migrations.firstWhereOrNull((m) => m.fromVersion == from);
      if (migration == null) {
        root.fail('schemaVersion', 'No migration from schema $version');
      }
      try {
        json = migration.migrate(json);
      } on StoryException {
        rethrow;
      } catch (error) {
        throw SerializationException(
          'Migration from schema $version failed',
          path: 'schemaVersion',
          cause: error,
        );
      }
      version++;
    }
    return JsonReader(json, '');
  }
}

// ---------------------------------------------------------------------------
// Encoding
// ---------------------------------------------------------------------------

final class _Encoder {
  JsonMap document(StoryDocument doc) => {
        'schemaVersion': StoryDocumentCodec.currentSchemaVersion,
        'id': doc.id,
        if (doc.title != null) 'title': doc.title,
        'revision': doc.revision,
        'canvas': canvas(doc.canvas, 'canvas'),
        if (doc.assets.isNotEmpty)
          'assets': [
            for (final (i, asset) in doc.assets.indexed)
              this.asset(asset, 'assets[$i]'),
          ],
        'groups': [
          for (final (i, group) in doc.groups.indexed)
            this.group(group, 'groups[$i]'),
        ],
        if (doc.createdAt case final createdAt?) 'createdAt': _date(createdAt),
        if (doc.updatedAt case final updatedAt?) 'updatedAt': _date(updatedAt),
        ..._annotations(doc.metadata, doc.customData),
      };

  JsonMap canvas(StoryCanvasConfiguration canvas, String path) => {
        'width': canvas.width,
        'height': canvas.height,
        'background': background(canvas.background, '$path.background'),
        if (canvas.safeArea != StoryInsets.zero)
          'safeArea': _insets(canvas.safeArea),
        'scaling': canvas.scalingBehavior.name,
      };

  JsonMap asset(StoryAsset asset, String path) => {
        'id': asset.id,
        'type': asset.type.name,
        'source': source(asset.source, '$path.source'),
        if (asset.mimeType != null) 'mimeType': asset.mimeType,
        if (asset.metadata.isNotEmpty) 'metadata': asset.metadata,
      };

  JsonMap group(StoryGroup group, String path) => {
        'id': group.id,
        if (group.title != null) 'title': group.title,
        'items': [
          for (final (i, item) in group.items.indexed)
            this.item(item, '$path.items[$i]'),
        ],
        if (group.createdAt case final createdAt?)
          'createdAt': _date(createdAt),
        if (group.expiresAt case final expiresAt?)
          'expiresAt': _date(expiresAt),
        ..._annotations(group.metadata, group.customData),
      };

  JsonMap item(StoryItem item, String path) => {
        'id': item.id,
        if (item.background case final itemBackground?)
          'background': background(itemBackground, '$path.background'),
        if (item.duration case final itemDuration?)
          'duration': duration(itemDuration),
        if (item.transition case final itemTransition?)
          'transition': transition(itemTransition),
        if (!item.playback.isInherited)
          'playback': {
            if (item.playback.autoAdvance != null)
              'autoAdvance': item.playback.autoAdvance,
          },
        'elements': [
          for (final (i, element) in item.elements.indexed)
            this.element(element, '$path.elements[$i]'),
        ],
        ..._annotations(item.metadata, item.customData),
      };

  JsonMap duration(StoryItemDuration duration) => switch (duration) {
        FixedItemDuration(:final duration) => {
            'kind': 'fixed',
            'ms': duration.inMilliseconds,
          },
        MediaItemDuration(
          :final elementId,
          :final maxDuration,
          :final fallback
        ) =>
          {
            'kind': 'media',
            if (elementId != null) 'elementId': elementId,
            if (maxDuration != null) 'maxMs': maxDuration.inMilliseconds,
            if (fallback != null) 'fallbackMs': fallback.inMilliseconds,
          },
        IndefiniteItemDuration() => {'kind': 'indefinite'},
        CustomItemDuration(:final providerId, :final data) => {
            'kind': 'custom',
            'providerId': providerId,
            if (data.isNotEmpty) 'data': data,
          },
      };

  JsonMap transition(StoryTransitionConfiguration transition) => {
        'type': transition.type,
        'ms': transition.duration.inMilliseconds,
        'curve': transition.curve,
        if (transition.parameters.isNotEmpty)
          'parameters': transition.parameters,
      };

  JsonMap element(StoryElement element, String path) {
    final common = <String, Object?>{
      'type': element.type,
      'id': element.id,
      'transform': _transform(element.transform),
      'opacity': element.opacity,
      'zIndex': element.zIndex,
      'visible': element.visible,
      'locked': element.locked,
      if (element.semanticLabel != null) 'semanticLabel': element.semanticLabel,
      ..._annotations(element.metadata, element.customData),
    };
    final specific = switch (element) {
      ImageElement() => {
          'source': source(element.source, '$path.source'),
          'fit': element.fit.name,
        },
      VideoElement() => {
          'source': source(element.source, '$path.source'),
          'fit': element.fit.name,
          if (element.poster case final poster?)
            'poster': source(poster, '$path.poster'),
          ..._timedMedia(element),
        },
      AudioElement() => {
          'source': source(element.source, '$path.source'),
          ..._timedMedia(element),
        },
      TextElement() => {
          'text': element.text,
          'style': _textStyle(element.style),
          'align': element.align.name,
          if (element.backgroundColor case final backgroundColor?)
            'backgroundColor': backgroundColor.toHex(),
          if (element.padding != StoryInsets.zero)
            'padding': _insets(element.padding),
        },
      StickerElement() => {
          'sticker': _sticker(element.sticker, '$path.sticker'),
        },
      ShapeElement() => {
          'shape': element.shape.name,
          if (element.fillColor case final fillColor?)
            'fillColor': fillColor.toHex(),
          if (element.stroke case final stroke?) 'stroke': _stroke(stroke),
          if (element.cornerRadius != 0) 'cornerRadius': element.cornerRadius,
        },
      DrawingElement() => {
          'strokes': [
            for (final stroke in element.strokes) _drawingStroke(stroke),
          ],
        },
      WidgetElement() => {
          'widgetType': element.widgetType,
          if (element.data.isNotEmpty) 'data': element.data,
        },
      CustomElement() => {
          'customType': element.customType,
          if (element.data.isNotEmpty) 'data': element.data,
        },
      InteractiveElement(:final interaction, :final accentColor) => {
          'interaction': _interaction(interaction),
          if (accentColor != null) 'accentColor': accentColor.toHex(),
        },
      // Preserve everything we did not understand, overlaid with the common
      // fields so edits like moving or hiding are kept.
      UnknownElement() => element.rawJson,
    };
    return {...specific, ...common};
  }

  JsonMap _timedMedia(TimedMediaElement element) => {
        'volume': element.volume,
        'muted': element.muted,
        'loop': element.loop,
        if (element.trimStart != Duration.zero)
          'trimStartMs': element.trimStart.inMilliseconds,
        if (element.trimEnd case final trimEnd?)
          'trimEndMs': trimEnd.inMilliseconds,
      };

  JsonMap background(StoryBackground background, String path) =>
      switch (background) {
        StoryColorBackground(:final color) => {
            'kind': 'color',
            'color': color.toHex(),
          },
        StoryGradientBackground() => {
            'kind': 'gradient',
            'colors': [for (final c in background.colors) c.toHex()],
            if (background.stops != null) 'stops': background.stops,
            'begin': _point(background.begin),
            'end': _point(background.end),
          },
        StoryMediaBackground(:final source, :final fit) => {
            'kind': 'media',
            'source': this.source(source, '$path.source'),
            'fit': fit.name,
          },
      };

  JsonMap source(StorySource source, String path) => switch (source) {
        NetworkStorySource(:final url) => {
            'kind': 'network',
            'url': url.toString(),
          },
        FileStorySource(:final path) => {'kind': 'file', 'path': path},
        AssetStorySource(:final name, :final package) => {
            'kind': 'asset',
            'name': name,
            if (package != null) 'package': package,
          },
        MemoryStorySource(:final bytes, :final mimeType) => {
            'kind': 'memory',
            'data': base64Encode(bytes),
            if (mimeType != null) 'mimeType': mimeType,
          },
        StreamStorySource() => throw SerializationException(
            'Stream sources are runtime-only and cannot be serialized; '
            'persist the media and use a file, network, or asset source',
            path: path,
          ),
        CustomStorySource(:final type, :final data) => {
            'kind': 'custom',
            'type': type,
            if (data.isNotEmpty) 'data': data,
          },
        ReferenceStorySource(:final assetId) => {
            'kind': 'reference',
            'assetId': assetId,
          },
      };

  JsonMap _interaction(StoryInteraction interaction) {
    List<JsonMap> choices(List<StoryChoice> list) => [
          for (final choice in list) {'id': choice.id, 'label': choice.label},
        ];
    return {
      'kind': interaction.kind,
      ...switch (interaction) {
        StoryPoll(:final question, choices: final options) => {
            'question': question,
            'choices': choices(options),
          },
        StoryQuiz(
          :final question,
          choices: final options,
          :final correctChoiceId,
        ) =>
          {
            'question': question,
            'choices': choices(options),
            'correctChoiceId': correctChoiceId,
          },
        StoryQuestion(:final prompt, :final placeholder) => {
            'prompt': prompt,
            'placeholder': placeholder,
          },
        StorySlider(:final question, :final emoji) => {
            'question': question,
            'emoji': emoji,
          },
        StoryCountdown(:final title, :final endsAt) => {
            'title': title,
            'endsAt': _date(endsAt),
          },
        StoryLink(:final url, :final label) => {
            'url': url.toString(),
            'label': label,
          },
        StoryProductTag(:final productId, :final name, :final priceLabel) => {
            'productId': productId,
            'name': name,
            if (priceLabel != null) 'priceLabel': priceLabel,
          },
        StoryCustomInteraction(:final type, :final data) => {
            'type': type,
            if (data.isNotEmpty) 'data': data,
          },
      },
    };
  }

  JsonMap _sticker(StickerContent sticker, String path) => switch (sticker) {
        EmojiSticker(:final emoji) => {'kind': 'emoji', 'emoji': emoji},
        ImageSticker(:final source, :final animated) => {
            'kind': 'image',
            'source': this.source(source, '$path.source'),
            'animated': animated,
          },
        CustomSticker(:final providerId, :final stickerId, :final data) => {
            'kind': 'custom',
            'providerId': providerId,
            'stickerId': stickerId,
            if (data.isNotEmpty) 'data': data,
          },
      };

  JsonMap _textStyle(StoryTextStyle style) => {
        if (style.fontFamily != null) 'fontFamily': style.fontFamily,
        'fontSize': style.fontSize,
        'fontWeight': style.fontWeight,
        if (style.italic) 'italic': true,
        'color': style.color.toHex(),
        if (style.lineHeight != null) 'lineHeight': style.lineHeight,
        if (style.letterSpacing != 0) 'letterSpacing': style.letterSpacing,
        if (style.shadows.isNotEmpty)
          'shadows': [
            for (final shadow in style.shadows)
              {
                'color': shadow.color.toHex(),
                'offset': _point(shadow.offset),
                'blurRadius': shadow.blurRadius,
              },
          ],
        if (style.stroke case final stroke?) 'stroke': _stroke(stroke),
      };

  /// Points are stored as a flat `[x0, y0, x1, y1, ...]` list to keep
  /// drawings compact.
  JsonMap _drawingStroke(StoryDrawingStroke stroke) => {
        'tool': stroke.tool.name,
        'color': stroke.color.toHex(),
        'width': stroke.width,
        'opacity': stroke.opacity,
        'points': [
          for (final point in stroke.points) ...[point.x, point.y],
        ],
      };

  JsonMap _stroke(StoryStroke stroke) =>
      {'color': stroke.color.toHex(), 'width': stroke.width};

  JsonMap _transform(StoryTransform transform) => {
        'x': transform.position.x,
        'y': transform.position.y,
        'width': transform.size.width,
        'height': transform.size.height,
        'rotation': transform.rotation,
        'scale': transform.scale,
        if (transform.flipHorizontal) 'flipHorizontal': true,
        if (transform.flipVertical) 'flipVertical': true,
      };

  JsonMap _point(StoryPoint point) => {'x': point.x, 'y': point.y};

  JsonMap _insets(StoryInsets insets) => {
        'left': insets.left,
        'top': insets.top,
        'right': insets.right,
        'bottom': insets.bottom,
      };

  String _date(DateTime value) => value.toUtc().toIso8601String();

  JsonMap _annotations(JsonMap metadata, JsonMap customData) => {
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (customData.isNotEmpty) 'customData': customData,
      };
}

// ---------------------------------------------------------------------------
// Decoding
// ---------------------------------------------------------------------------

const Set<String> _commonElementKeys = {
  'type',
  'id',
  'transform',
  'opacity',
  'zIndex',
  'visible',
  'locked',
  'semanticLabel',
  'metadata',
  'customData',
};

final class _Decoder {
  _Decoder(this.unknownElementPolicy);

  final UnknownElementPolicy unknownElementPolicy;

  StoryDocument document(JsonReader json) => StoryDocument(
        id: json.string('id'),
        title: json.optionalString('title'),
        revision: json.integer('revision', fallback: 0),
        canvas: json.has('canvas')
            ? canvas(json.child('canvas'))
            : StoryCanvasConfiguration.portrait,
        assets: [for (final a in json.children('assets')) asset(a)],
        groups: [for (final g in json.children('groups')) group(g)],
        createdAt: json.optionalDateTime('createdAt'),
        updatedAt: json.optionalDateTime('updatedAt'),
        metadata: _jsonData(json, 'metadata'),
        customData: _jsonData(json, 'customData'),
      );

  StoryCanvasConfiguration canvas(JsonReader json) => StoryCanvasConfiguration(
        width: json.number('width'),
        height: json.number('height'),
        background: json.has('background')
            ? background(json.child('background'))
            : const StoryColorBackground(StoryColor.black),
        safeArea: json.has('safeArea')
            ? _insets(json.child('safeArea'))
            : StoryInsets.zero,
        scalingBehavior: json.enumValue('scaling', StoryScalingBehavior.values,
            StoryScalingBehavior.contain),
      );

  StoryAsset asset(JsonReader json) {
    final assetSource = source(json.child('source'));
    if (assetSource is ReferenceStorySource) {
      json.fail('source', 'An asset cannot reference another asset');
    }
    return StoryAsset(
      id: json.string('id'),
      type: json.enumValue('type', StoryAssetType.values, StoryAssetType.other),
      source: assetSource,
      mimeType: json.optionalString('mimeType'),
      metadata: _jsonData(json, 'metadata'),
    );
  }

  StoryGroup group(JsonReader json) => StoryGroup(
        id: json.string('id'),
        title: json.optionalString('title'),
        items: [for (final i in json.children('items')) item(i)],
        createdAt: json.optionalDateTime('createdAt'),
        expiresAt: json.optionalDateTime('expiresAt'),
        metadata: _jsonData(json, 'metadata'),
        customData: _jsonData(json, 'customData'),
      );

  StoryItem item(JsonReader json) {
    final playback = json.optionalChild('playback');
    return StoryItem(
      id: json.string('id'),
      background:
          json.has('background') ? background(json.child('background')) : null,
      duration: json.has('duration') ? duration(json.child('duration')) : null,
      transition:
          json.has('transition') ? transition(json.child('transition')) : null,
      playback: playback == null
          ? StoryItemPlaybackConfiguration.inherit
          : StoryItemPlaybackConfiguration(
              autoAdvance: playback.has('autoAdvance')
                  ? playback.boolean('autoAdvance', fallback: true)
                  : null,
            ),
      elements: [
        for (final e in json.children('elements'))
          if (element(e) case final decoded?) decoded,
      ],
      metadata: _jsonData(json, 'metadata'),
      customData: _jsonData(json, 'customData'),
    );
  }

  StoryItemDuration duration(JsonReader json) {
    return switch (json.string('kind')) {
      'fixed' => FixedItemDuration(json.duration('ms')),
      'media' => MediaItemDuration(
          elementId: json.optionalString('elementId'),
          maxDuration: json.optionalDuration('maxMs'),
          fallback: json.optionalDuration('fallbackMs'),
        ),
      'indefinite' => const IndefiniteItemDuration(),
      'custom' => CustomItemDuration(
          json.string('providerId'),
          data: _jsonData(json, 'data'),
        ),
      final kind => json.fail('kind', 'Unknown duration kind "$kind"'),
    };
  }

  StoryTransitionConfiguration transition(JsonReader json) =>
      StoryTransitionConfiguration(
        type: json.string('type'),
        duration:
            json.duration('ms', fallback: const Duration(milliseconds: 300)),
        curve: json.optionalString('curve') ?? 'easeInOut',
        parameters: _jsonData(json, 'parameters'),
      );

  /// Returns `null` when an unknown element is skipped.
  StoryElement? element(JsonReader json) {
    final type = json.string('type');
    final id = json.string('id');
    final transform = json.has('transform')
        ? _transform(json.child('transform'))
        : const StoryTransform(position: StoryPoint.zero, size: StorySize.zero);
    final opacity = json.number('opacity', fallback: 1);
    final zIndex = json.integer('zIndex', fallback: 0);
    final visible = json.boolean('visible', fallback: true);
    final locked = json.boolean('locked', fallback: false);
    final semanticLabel = json.optionalString('semanticLabel');
    final metadata = _jsonData(json, 'metadata');
    final customData = _jsonData(json, 'customData');

    switch (type) {
      case ImageElement.typeId:
        return ImageElement(
          id: id,
          transform: transform,
          source: source(json.child('source')),
          fit: json.enumValue('fit', StoryFit.values, StoryFit.cover),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case VideoElement.typeId:
        return VideoElement(
          id: id,
          transform: transform,
          source: source(json.child('source')),
          fit: json.enumValue('fit', StoryFit.values, StoryFit.cover),
          poster: json.has('poster') ? source(json.child('poster')) : null,
          volume: json.number('volume', fallback: 1),
          muted: json.boolean('muted', fallback: false),
          loop: json.boolean('loop', fallback: false),
          trimStart: json.duration('trimStartMs', fallback: Duration.zero),
          trimEnd: json.optionalDuration('trimEndMs'),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case AudioElement.typeId:
        return AudioElement(
          id: id,
          transform: transform,
          source: source(json.child('source')),
          volume: json.number('volume', fallback: 1),
          muted: json.boolean('muted', fallback: false),
          loop: json.boolean('loop', fallback: false),
          trimStart: json.duration('trimStartMs', fallback: Duration.zero),
          trimEnd: json.optionalDuration('trimEndMs'),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case TextElement.typeId:
        return TextElement(
          id: id,
          transform: transform,
          text: json.string('text'),
          style: json.has('style') ? _textStyle(json.child('style')) : null,
          align: json.enumValue(
              'align', StoryTextAlign.values, StoryTextAlign.center),
          backgroundColor: _optionalColor(json, 'backgroundColor'),
          padding: json.has('padding')
              ? _insets(json.child('padding'))
              : StoryInsets.zero,
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case StickerElement.typeId:
        return StickerElement(
          id: id,
          transform: transform,
          sticker: _sticker(json.child('sticker')),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case ShapeElement.typeId:
        return ShapeElement(
          id: id,
          transform: transform,
          shape: json.enumValue(
              'shape', StoryShapeType.values, StoryShapeType.rectangle),
          fillColor: _optionalColor(json, 'fillColor'),
          stroke: json.has('stroke') ? _stroke(json.child('stroke')) : null,
          cornerRadius: json.number('cornerRadius', fallback: 0),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case DrawingElement.typeId:
        return DrawingElement(
          id: id,
          transform: transform,
          strokes: [
            for (final stroke in json.children('strokes'))
              _drawingStroke(stroke),
          ],
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case WidgetElement.typeId:
        return WidgetElement(
          id: id,
          transform: transform,
          widgetType: json.string('widgetType'),
          data: _jsonData(json, 'data'),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case InteractiveElement.typeId
          when _interactionKinds.contains(
              json.optionalChild('interaction')?.optionalString('kind')):
        return InteractiveElement(
          id: id,
          transform: transform,
          interaction: _interaction(json.child('interaction')),
          accentColor: _optionalColor(json, 'accentColor'),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
      case CustomElement.typeId:
        return CustomElement(
          id: id,
          transform: transform,
          customType: json.string('customType'),
          data: _jsonData(json, 'data'),
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
    }

    switch (unknownElementPolicy) {
      case UnknownElementPolicy.skip:
        return null;
      case UnknownElementPolicy.error:
        json.fail('type', 'Unknown element type "$type"');
      case UnknownElementPolicy.preserve:
        return UnknownElement(
          id: id,
          transform: transform,
          originalType: type,
          rawJson: {
            for (final entry in json.json.entries)
              if (!_commonElementKeys.contains(entry.key))
                entry.key: entry.value,
          },
          opacity: opacity,
          zIndex: zIndex,
          visible: visible,
          locked: locked,
          semanticLabel: semanticLabel,
          metadata: metadata,
          customData: customData,
        );
    }
  }

  StoryBackground background(JsonReader json) {
    return switch (json.string('kind')) {
      'color' => StoryColorBackground(_color(json, 'color')),
      'gradient' => StoryGradientBackground(
          colors: [
            for (final (i, value) in json.list('colors').indexed)
              _parseColor(value, '${json.pathOf('colors')}[$i]'),
          ],
          stops: json.has('stops') ? json.numbers('stops') : null,
          begin: json.has('begin')
              ? _point(json.child('begin'))
              : const StoryPoint(0, -1),
          end: json.has('end')
              ? _point(json.child('end'))
              : const StoryPoint(0, 1),
        ),
      'media' => StoryMediaBackground(
          source(json.child('source')),
          fit: json.enumValue('fit', StoryFit.values, StoryFit.cover),
        ),
      final kind => json.fail('kind', 'Unknown background kind "$kind"'),
    };
  }

  StorySource source(JsonReader json) {
    return switch (json.string('kind')) {
      'network' => NetworkStorySource(_uri(json, 'url')),
      'file' => FileStorySource(json.string('path')),
      'asset' => AssetStorySource(
          json.string('name'),
          package: json.optionalString('package'),
        ),
      'memory' => MemoryStorySource(
          _base64(json, 'data'),
          mimeType: json.optionalString('mimeType'),
        ),
      'custom' => CustomStorySource(
          json.string('type'),
          data: _jsonData(json, 'data'),
        ),
      'reference' => ReferenceStorySource(json.string('assetId')),
      final kind => json.fail('kind', 'Unknown source kind "$kind"'),
    };
  }

  /// Interaction kinds this version understands. An interactive element with
  /// any other kind is handled like an unknown element type, so documents
  /// from newer versions keep it intact.
  static const Set<String> _interactionKinds = {
    StoryPoll.kindId,
    StoryQuiz.kindId,
    StoryQuestion.kindId,
    StorySlider.kindId,
    StoryCountdown.kindId,
    StoryLink.kindId,
    StoryProductTag.kindId,
    StoryCustomInteraction.kindId,
  };

  StoryInteraction _interaction(JsonReader json) {
    List<StoryChoice> choices() => [
          for (final choice in json.children('choices'))
            StoryChoice(id: choice.string('id'), label: choice.string('label')),
        ];
    return switch (json.string('kind')) {
      StoryPoll.kindId =>
        StoryPoll(question: json.string('question'), choices: choices()),
      StoryQuiz.kindId => StoryQuiz(
          question: json.string('question'),
          choices: choices(),
          correctChoiceId: json.string('correctChoiceId'),
        ),
      StoryQuestion.kindId => StoryQuestion(
          prompt: json.string('prompt'),
          placeholder: json.optionalString('placeholder') ?? 'Type something…',
        ),
      StorySlider.kindId => StorySlider(
          question: json.string('question'),
          emoji: json.optionalString('emoji') ?? '😍',
        ),
      StoryCountdown.kindId => StoryCountdown(
          title: json.string('title'),
          endsAt: json.optionalDateTime('endsAt') ??
              json.fail('endsAt', 'Missing required timestamp'),
        ),
      StoryLink.kindId =>
        StoryLink(url: _uri(json, 'url'), label: json.string('label')),
      StoryProductTag.kindId => StoryProductTag(
          productId: json.string('productId'),
          name: json.string('name'),
          priceLabel: json.optionalString('priceLabel'),
        ),
      StoryCustomInteraction.kindId => StoryCustomInteraction(
          json.string('type'),
          data: _jsonData(json, 'data'),
        ),
      final kind => json.fail('kind', 'Unknown interaction kind "$kind"'),
    };
  }

  StickerContent _sticker(JsonReader json) {
    return switch (json.string('kind')) {
      'emoji' => EmojiSticker(json.string('emoji')),
      'image' => ImageSticker(
          source(json.child('source')),
          animated: json.boolean('animated', fallback: false),
        ),
      'custom' => CustomSticker(
          providerId: json.string('providerId'),
          stickerId: json.string('stickerId'),
          data: _jsonData(json, 'data'),
        ),
      final kind => json.fail('kind', 'Unknown sticker kind "$kind"'),
    };
  }

  StoryTextStyle _textStyle(JsonReader json) => StoryTextStyle(
        fontFamily: json.optionalString('fontFamily'),
        fontSize: json.number('fontSize', fallback: 48),
        fontWeight: json.integer('fontWeight', fallback: 400),
        italic: json.boolean('italic', fallback: false),
        color: json.has('color') ? _color(json, 'color') : StoryColor.white,
        lineHeight: json.optionalNumber('lineHeight'),
        letterSpacing: json.number('letterSpacing', fallback: 0),
        shadows: [
          for (final shadow in json.children('shadows'))
            StoryShadow(
              color: _color(shadow, 'color'),
              offset: shadow.has('offset')
                  ? _point(shadow.child('offset'))
                  : StoryPoint.zero,
              blurRadius: shadow.number('blurRadius', fallback: 0),
            ),
        ],
        stroke: json.has('stroke') ? _stroke(json.child('stroke')) : null,
      );

  StoryDrawingStroke _drawingStroke(JsonReader json) {
    final coordinates = json.numbers('points');
    if (coordinates.length.isOdd) {
      json.fail('points', 'Expected an even number of coordinates');
    }
    return StoryDrawingStroke(
      tool:
          json.enumValue('tool', StoryDrawingTool.values, StoryDrawingTool.pen),
      color: json.has('color') ? _color(json, 'color') : StoryColor.white,
      width: json.number('width', fallback: 8),
      opacity: json.number('opacity', fallback: 1),
      points: [
        for (var i = 0; i < coordinates.length; i += 2)
          StoryPoint(coordinates[i], coordinates[i + 1]),
      ],
    );
  }

  StoryStroke _stroke(JsonReader json) =>
      StoryStroke(color: _color(json, 'color'), width: json.number('width'));

  StoryTransform _transform(JsonReader json) => StoryTransform(
        position: StoryPoint(json.number('x'), json.number('y')),
        size: StorySize(json.number('width'), json.number('height')),
        rotation: json.number('rotation', fallback: 0),
        scale: json.number('scale', fallback: 1),
        flipHorizontal: json.boolean('flipHorizontal', fallback: false),
        flipVertical: json.boolean('flipVertical', fallback: false),
      );

  StoryPoint _point(JsonReader json) =>
      StoryPoint(json.number('x'), json.number('y'));

  StoryInsets _insets(JsonReader json) => StoryInsets.only(
        left: json.number('left', fallback: 0),
        top: json.number('top', fallback: 0),
        right: json.number('right', fallback: 0),
        bottom: json.number('bottom', fallback: 0),
      );

  StoryColor _color(JsonReader json, String key) =>
      _parseColor(json.string(key), json.pathOf(key));

  StoryColor? _optionalColor(JsonReader json, String key) =>
      json.has(key) ? _color(json, key) : null;

  StoryColor _parseColor(Object? value, String path) {
    if (value is String) {
      try {
        return StoryColor.parse(value);
      } on FormatException {
        // Reported below with the path.
      }
    }
    throw SerializationException('Expected a #RRGGBB or #AARRGGBB color',
        path: path);
  }

  Uri _uri(JsonReader json, String key) {
    final value = json.string(key);
    return Uri.tryParse(value) ?? json.fail(key, 'Invalid URL');
  }

  Uint8List _base64(JsonReader json, String key) {
    try {
      return base64Decode(json.string(key));
    } on FormatException catch (error) {
      throw SerializationException('Invalid base64 data',
          path: json.pathOf(key), cause: error);
    }
  }

  JsonMap _jsonData(JsonReader json, String key) {
    final value = json.map(key);
    if (!isJsonCompatible(value)) json.fail(key, 'Expected JSON data');
    return value;
  }
}
