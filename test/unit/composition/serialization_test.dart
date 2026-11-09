import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/composition.dart';

import '../../fixtures/sample_document.dart';

Matcher throwsSerializationAt(String path) => throwsA(
      isA<SerializationException>().having((e) => e.path, 'path', path),
    );

/// The elements of the first item of the first group in encoded [json].
List<Object?> firstElements(JsonMap json) {
  final group = (json['groups'] as List<Object?>).first as JsonMap;
  final item = (group['items'] as List<Object?>).first as JsonMap;
  return item['elements'] as List<Object?>;
}

JsonMap minimalJson({List<Object?> elements = const []}) => {
      'schemaVersion': 1,
      'id': 'd',
      'groups': [
        {
          'id': 'g',
          'items': [
            {'id': 'i', 'elements': elements},
          ],
        },
      ],
    };

void main() {
  const codec = StoryDocumentCodec();

  group('round trip', () {
    test('every model survives encode and decode', () {
      final document = sampleDocument();
      final restored = codec.decode(codec.encode(document));
      expect(restored, document);
    });

    test('survives a trip through a JSON string', () {
      final document = sampleDocument();
      final text = codec.encodeToString(document, pretty: true);
      expect(codec.decodeFromString(text), document);
      // Encoding is deterministic.
      expect(codec.encodeToString(codec.decodeFromString(text), pretty: true),
          text);
    });

    test('encoded output is plain JSON with a schema version', () {
      final json = codec.encode(sampleDocument());
      expect(json['schemaVersion'], StoryDocumentCodec.currentSchemaVersion);
      expect(() => jsonEncode(json), returnsNormally);
      expect(isJsonCompatible(json), isTrue);
    });

    test('drawing points are stored as a flat list', () {
      final json = codec.encode(sampleDocument());
      final elements = firstElements(json);
      final drawing = elements
          .cast<JsonMap>()
          .firstWhere((element) => element['type'] == 'drawing');
      final stroke = (drawing['strokes'] as List<Object?>).first as JsonMap;
      expect(stroke['points'], [0.0, 0.0, 10.5, 20.0]);
    });

    test('defaults are applied for omitted optional fields', () {
      final document = codec.decode(minimalJson(elements: [
        {
          'type': 'text',
          'id': 't',
          'text': 'hi',
          'transform': {'x': 1, 'y': 2, 'width': 3, 'height': 4},
        },
      ]));
      expect(document.canvas, StoryCanvasConfiguration.portrait);
      final text =
          document.groups.single.items.single.elements.single as TextElement;
      expect(text.opacity, 1);
      expect(text.visible, isTrue);
      expect(text.transform.scale, 1);
      expect(text.style, StoryTextStyle());
      expect(text.align, StoryTextAlign.center);
    });

    test('timestamps are written in UTC', () {
      final document = StoryDocument(
        id: 'd',
        createdAt: DateTime.utc(2026, 5, 1, 10),
      );
      expect(codec.encode(document)['createdAt'], '2026-05-01T10:00:00.000Z');
    });
  });

  group('unknown elements', () {
    JsonMap futureJson() => minimalJson(elements: [
          {
            'type': 'lottie',
            'id': 'anim',
            'transform': {'x': 10, 'y': 20, 'width': 30, 'height': 40},
            'zIndex': 3,
            'animation': {'src': 'a.json', 'speed': 2},
          },
        ]);

    test('are preserved by default and re-encode losslessly', () {
      final document = codec.decode(futureJson());
      final element =
          document.groups.single.items.single.elements.single as UnknownElement;
      expect(element.type, 'lottie');
      expect(element.zIndex, 3);
      expect(element.rawJson['animation'], {'src': 'a.json', 'speed': 2});

      final reencoded = codec.encode(document);
      final json = firstElements(reencoded).single as JsonMap;
      expect(json['type'], 'lottie');
      expect(json['animation'], {'src': 'a.json', 'speed': 2});
    });

    test('keep edits to common fields when re-encoded', () {
      final document = codec.decode(futureJson());
      final element = document.groups.single.items.single.elements.single;
      final moved = element.copyWithCommon(visible: false);
      final item = document.groups.single.items.single.replaceElement(moved);
      final reencoded = codec.decode(codec.encode(document.copyWith(groups: [
        document.groups.single.copyWith(items: [item]),
      ])));
      final restored = reencoded.groups.single.items.single.elements.single;
      expect(restored.visible, isFalse);
      expect((restored as UnknownElement).rawJson['animation'], isNotNull);
    });

    test('can be skipped', () {
      const skipping =
          StoryDocumentCodec(unknownElementPolicy: UnknownElementPolicy.skip);
      expect(
        skipping.decode(futureJson()).groups.single.items.single.elements,
        isEmpty,
      );
    });

    test('can be rejected', () {
      const strict =
          StoryDocumentCodec(unknownElementPolicy: UnknownElementPolicy.error);
      expect(
        () => strict.decode(futureJson()),
        throwsSerializationAt('groups[0].items[0].elements[0].type'),
      );
    });
  });

  group('versioning', () {
    test('rejects documents from a newer schema', () {
      expect(
        () => codec.decode({...minimalJson(), 'schemaVersion': 99}),
        throwsSerializationAt('schemaVersion'),
      );
    });

    test('requires a schema version', () {
      expect(
        () => codec.decode({'id': 'd'}),
        throwsSerializationAt('schemaVersion'),
      );
    });

    test('applies migrations in order', () {
      // Pretend schema 0 stored the title under "name".
      final migrating = StoryDocumentCodec(migrations: [_RenameTitle()]);
      // Reuse the real schema number by faking an older version.
      final legacy = {
        ...minimalJson(),
        'schemaVersion': 0,
        'name': 'Legacy title',
      };
      expect(
        () => codec.decode(legacy),
        throwsSerializationAt('schemaVersion'),
        reason: 'version 0 is invalid without a migration path',
      );
      expect(migrating.decode(legacy).title, 'Legacy title');
    });

    test('wraps migration failures', () {
      final failing = StoryDocumentCodec(migrations: [_Throwing()]);
      expect(
        () => failing.decode({...minimalJson(), 'schemaVersion': 0}),
        throwsA(isA<SerializationException>()
            .having((e) => e.cause, 'cause', isA<StateError>())),
      );
    });
  });

  group('malformed input', () {
    test('reports invalid JSON text', () {
      expect(
        () => codec.decodeFromString('{not json'),
        throwsA(isA<SerializationException>()),
      );
    });

    test('reports a non-object root', () {
      expect(() => codec.decode([1, 2]), throwsSerializationAt(r'$'));
    });

    test('reports wrong types with a precise path', () {
      expect(
        () => codec.decode(minimalJson(elements: [
          {
            'type': 'image',
            'id': 'x',
            'transform': {'x': 'left', 'y': 0, 'width': 1, 'height': 1},
            'source': {'kind': 'file', 'path': '/a'},
          },
        ])),
        throwsSerializationAt('groups[0].items[0].elements[0].transform.x'),
      );
    });

    test('reports missing required fields', () {
      expect(
        () => codec.decode(minimalJson(elements: [
          {'type': 'image', 'id': 'x'},
        ])),
        throwsSerializationAt('groups[0].items[0].elements[0].source'),
      );
    });

    test('reports unknown enum values and kinds', () {
      expect(
        () => codec.decode(minimalJson(elements: [
          {
            'type': 'image',
            'id': 'x',
            'fit': 'squash',
            'source': {'kind': 'file', 'path': '/a'},
          },
        ])),
        throwsSerializationAt('groups[0].items[0].elements[0].fit'),
      );
      expect(
        () => codec.decode(minimalJson(elements: [
          {
            'type': 'image',
            'id': 'x',
            'source': {'kind': 'ftp'},
          },
        ])),
        throwsSerializationAt('groups[0].items[0].elements[0].source.kind'),
      );
    });

    test('reports bad colors', () {
      expect(
        () => codec.decode({
          ...minimalJson(),
          'canvas': {
            'width': 1,
            'height': 1,
            'background': {'kind': 'color', 'color': 'red'},
          },
        }),
        throwsSerializationAt('canvas.background.color'),
      );
    });

    test('rejects odd drawing coordinate counts', () {
      expect(
        () => codec.decode(minimalJson(elements: [
          {
            'type': 'drawing',
            'id': 'd',
            'strokes': [
              {
                'points': [1, 2, 3],
              },
            ],
          },
        ])),
        throwsSerializationAt(
            'groups[0].items[0].elements[0].strokes[0].points'),
      );
    });

    test('accepts whole-number doubles as integers', () {
      final document = codec.decode({...minimalJson(), 'revision': 2.0});
      expect(document.revision, 2);
      expect(
        () => codec.decode({...minimalJson(), 'revision': 2.5}),
        throwsSerializationAt('revision'),
      );
    });
  });

  test('stream sources cannot be encoded', () {
    final document = StoryDocument(id: 'd', groups: [
      StoryGroup(id: 'g', items: [
        StoryItem(id: 'i', elements: [
          VideoElement(
            id: 'v',
            transform: box(0, 0),
            source: StreamStorySource(() => const Stream.empty()),
          ),
        ]),
      ]),
    ]);
    expect(
      () => codec.encode(document),
      throwsSerializationAt('groups[0].items[0].elements[0].source'),
    );
  });
}

final class _RenameTitle implements StoryDocumentMigration {
  @override
  int get fromVersion => 0;

  @override
  JsonMap migrate(JsonMap json) {
    final upgraded = {...json, 'title': json['name']}..remove('name');
    return upgraded;
  }
}

final class _Throwing implements StoryDocumentMigration {
  @override
  int get fromVersion => 0;

  @override
  JsonMap migrate(JsonMap json) => throw StateError('boom');
}
