import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/composition.dart';

import '../../fixtures/sample_document.dart';

const validator = StoryDocumentValidator();

StoryDocument withElements(List<StoryElement> elements,
        {StoryItemDuration? duration}) =>
    StoryDocument(id: 'd', groups: [
      StoryGroup(id: 'g', items: [
        StoryItem(id: 'i', elements: elements, duration: duration),
      ]),
    ]);

Iterable<String> errorCodes(StoryDocument document) =>
    validator.validate(document).errors.map((issue) => issue.code);

Iterable<String> errorPaths(StoryDocument document) =>
    validator.validate(document).errors.map((issue) => issue.path);

void main() {
  test('the sample document is valid', () {
    final result = validator.validate(sampleDocument());
    expect(result.errors, isEmpty, reason: result.issues.join('\n'));
    expect(result.isValid, isTrue);
  });

  test('empty documents and groups produce warnings, not errors', () {
    final result = validator
        .validate(StoryDocument(id: 'd', groups: [StoryGroup(id: 'g')]));
    expect(result.isValid, isTrue);
    expect(result.warnings.map((w) => w.code), [StoryValidationCodes.empty]);
    expect(
      validator.validate(StoryDocument(id: 'd')).warnings.single.path,
      'groups',
    );
  });

  group('ids', () {
    test('must not be empty', () {
      expect(errorPaths(StoryDocument(id: ' ')), ['id']);
    });

    test('duplicate group and item ids are errors', () {
      final document = StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [StoryItem(id: 'i')]),
        StoryGroup(id: 'g', items: [StoryItem(id: 'i')]),
      ]);
      expect(errorPaths(document), ['groups[1].id', 'groups[1].items[0].id']);
      expect(errorCodes(document).toSet(), {StoryValidationCodes.duplicateId});
    });

    test('element ids must be unique within an item', () {
      final document = withElements([
        TextElement(id: 'x', transform: box(0, 0), text: 'a'),
        TextElement(id: 'x', transform: box(0, 0), text: 'b'),
      ]);
      expect(errorPaths(document), ['groups[0].items[0].elements[1].id']);
    });

    test('duplicate asset ids are errors', () {
      final asset = StoryAsset(
        id: 'a',
        type: StoryAssetType.image,
        source: const FileStorySource('/a'),
      );
      expect(
        errorPaths(StoryDocument(id: 'd', assets: [asset, asset])),
        ['assets[1].id'],
      );
    });
  });

  group('ranges', () {
    test('canvas dimensions must be positive', () {
      final document = StoryDocument(
        id: 'd',
        canvas: const StoryCanvasConfiguration(width: 0, height: double.nan),
      );
      expect(errorPaths(document), ['canvas.width', 'canvas.height']);
    });

    test('element opacity, scale, and size are checked', () {
      final document = withElements([
        ImageElement(
          id: 'x',
          transform: const StoryTransform(
            position: StoryPoint(0, 0),
            size: StorySize(-1, 10),
            scale: 0,
          ),
          source: const FileStorySource('/a'),
          opacity: 1.5,
        ),
      ]);
      const base = 'groups[0].items[0].elements[0]';
      expect(errorPaths(document), [
        '$base.transform.size',
        '$base.transform.scale',
        '$base.opacity',
      ]);
    });

    test('media volume and trim range are checked', () {
      final document = withElements([
        VideoElement(
          id: 'v',
          transform: box(0, 0),
          source: const FileStorySource('/v'),
          volume: 2,
          trimStart: const Duration(seconds: 5),
          trimEnd: const Duration(seconds: 3),
        ),
      ]);
      expect(errorPaths(document), [
        'groups[0].items[0].elements[0].volume',
        'groups[0].items[0].elements[0].trimEnd',
      ]);
    });

    test('text style is checked', () {
      final document = withElements([
        TextElement(
          id: 't',
          transform: box(0, 0),
          text: '  ',
          style: StoryTextStyle(fontSize: 0, fontWeight: 1000),
        ),
      ]);
      final result = validator.validate(document);
      expect(result.errors.map((e) => e.path), [
        'groups[0].items[0].elements[0].style.fontSize',
        'groups[0].items[0].elements[0].style.fontWeight',
      ]);
      expect(
          result.warnings.single.path, 'groups[0].items[0].elements[0].text');
    });

    test('fixed durations must be positive', () {
      expect(
        errorPaths(withElements(const [],
            duration: const FixedItemDuration(Duration.zero))),
        ['groups[0].items[0].duration'],
      );
    });

    test('gradients need two colors and matching stops', () {
      final document = StoryDocument(
        id: 'd',
        canvas: StoryCanvasConfiguration(
          width: 10,
          height: 10,
          background: StoryGradientBackground(
            colors: const [StoryColor.black],
            stops: const [0, 2],
          ),
        ),
      );
      expect(errorPaths(document),
          ['canvas.background.colors', 'canvas.background.stops']);
    });

    test('group expiry must follow creation', () {
      final document = StoryDocument(id: 'd', groups: [
        StoryGroup(
          id: 'g',
          createdAt: DateTime.utc(2026, 2),
          expiresAt: DateTime.utc(2026),
          items: [StoryItem(id: 'i')],
        ),
      ]);
      expect(errorCodes(document), [StoryValidationCodes.invalidTimeRange]);
    });
  });

  group('references', () {
    test('missing assets are reported where they are referenced', () {
      final document = withElements([
        StickerElement(
          id: 's',
          transform: box(0, 0),
          sticker: const ImageSticker(ReferenceStorySource('nope')),
        ),
      ]);
      expect(
        errorPaths(document),
        ['groups[0].items[0].elements[0].sticker.source.assetId'],
      );
    });

    test('media durations must point at a time-based element', () {
      final text = TextElement(id: 't', transform: box(0, 0), text: 'x');
      expect(
        errorPaths(withElements([text],
            duration: const MediaItemDuration(elementId: 't'))),
        ['groups[0].items[0].duration.elementId'],
      );
      expect(
        errorPaths(withElements([text], duration: const MediaItemDuration())),
        ['groups[0].items[0].duration'],
      );
      expect(
        errorPaths(withElements([
          AudioElement(id: 'a', source: const FileStorySource('/a')),
        ], duration: const MediaItemDuration())),
        isEmpty,
      );
    });

    test('network sources must use http(s)', () {
      final document = withElements([
        ImageElement(
          id: 'x',
          transform: box(0, 0),
          source: NetworkStorySource(Uri.parse('ftp://example.com/a.png')),
        ),
      ]);
      expect(
          errorPaths(document), ['groups[0].items[0].elements[0].source.url']);
    });

    test('stream sources warn that they cannot be saved', () {
      final result = validator.validate(withElements([
        VideoElement(
          id: 'v',
          transform: box(0, 0),
          source: StreamStorySource(() => const Stream.empty()),
        ),
      ]));
      expect(result.isValid, isTrue);
      expect(result.warnings.single.code, StoryValidationCodes.notSerializable);
    });
  });

  test('custom rules run after built-in checks', () {
    final custom = StoryDocumentValidator(rules: [_RequireTitle()]);
    final result = custom.validate(StoryDocument(id: 'd'));
    expect(result.errors.single.code, 'missing_title');
  });

  test('validateOrThrow raises InvalidCompositionException', () {
    expect(
      () => validator.validateOrThrow(StoryDocument(id: '')),
      throwsA(isA<InvalidCompositionException>()
          .having((e) => e.issues.first.path, 'path', 'id')),
    );
    expect(() => validator.validateOrThrow(sampleDocument()), returnsNormally);
  });
}

final class _RequireTitle implements StoryValidationRule {
  @override
  Iterable<StoryValidationIssue> validate(StoryDocument document) sync* {
    if (document.title == null) {
      yield const StoryValidationIssue.error('missing_title', 'Needs a title',
          path: 'title');
    }
  }
}
