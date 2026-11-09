import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/composition.dart';

import '../../fixtures/sample_document.dart';

void main() {
  group('StoryElement', () {
    test('equality is structural and type-aware', () {
      final a = ImageElement(
        id: 'x',
        transform: box(1, 1),
        source: const FileStorySource('/a.png'),
      );
      final b = ImageElement(
        id: 'x',
        transform: box(1, 1),
        source: const FileStorySource('/a.png'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(fit: StoryFit.fill)));
      expect(
        a,
        isNot(VideoElement(
          id: 'x',
          transform: box(1, 1),
          source: const FileStorySource('/a.png'),
        )),
      );
    });

    test('copyWithCommon preserves type-specific fields', () {
      final text = TextElement(id: 't', transform: box(0, 0), text: 'Hi');
      final moved = text.copyWithCommon(
        transform: text.transform.translate(const StoryPoint(10, 5)),
        locked: true,
      );
      expect(moved, isA<TextElement>());
      expect(moved.text, 'Hi');
      expect(moved.transform.position, const StoryPoint(10, 5));
      expect(moved.locked, isTrue);
      expect(text.locked, isFalse, reason: 'originals are never mutated');
    });

    test('time-based elements are identified', () {
      final video = VideoElement(
          id: 'v', transform: box(0, 0), source: const FileStorySource('/v'));
      final audio =
          AudioElement(id: 'a', source: const FileStorySource('/a.mp3'));
      expect(video.isTimeBased, isTrue);
      expect(audio.isTimeBased, isTrue);
      expect(audio.transform.size, StorySize.zero);
      expect(
        TextElement(id: 't', transform: box(0, 0), text: '').isTimeBased,
        isFalse,
      );
    });

    test('transform bounds account for scale around the center', () {
      const transform = StoryTransform(
        position: StoryPoint(100, 100),
        size: StorySize(50, 20),
        scale: 2,
      );
      expect(
        transform.unrotatedBounds,
        const StoryRect.fromLTWH(50, 80, 100, 40),
      );
    });
  });

  group('StoryItem', () {
    test('paint order is stable for equal z-index', () {
      final item = StoryItem(id: 'i', elements: [
        TextElement(id: 'top', transform: box(0, 0), text: '', zIndex: 5),
        TextElement(id: 'a', transform: box(0, 0), text: ''),
        TextElement(id: 'bottom', transform: box(0, 0), text: '', zIndex: -1),
        TextElement(id: 'b', transform: box(0, 0), text: ''),
      ]);
      expect(
        item.elementsInPaintOrder.map((e) => e.id),
        ['bottom', 'a', 'b', 'top'],
      );
      expect(item.elements.first.id, 'top', reason: 'list order untouched');
    });

    test('element lists are unmodifiable', () {
      final elements = <StoryElement>[
        TextElement(id: 'a', transform: box(0, 0), text: ''),
      ];
      final item = StoryItem(id: 'i', elements: elements);
      elements.clear();
      expect(item.elements, hasLength(1));
      expect(item.elements.clear, throwsUnsupportedError);
    });

    test('replaceElement swaps by id and shares other elements', () {
      final keep = TextElement(id: 'keep', transform: box(0, 0), text: 'k');
      final change = TextElement(id: 'change', transform: box(0, 0), text: 'c');
      final item = StoryItem(id: 'i', elements: [keep, change]);
      final updated = item.replaceElement(change.copyWith(text: 'changed'));
      expect((updated.elements[1] as TextElement).text, 'changed');
      expect(identical(updated.elements[0], keep), isTrue);
      expect(
        identical(
          item.replaceElement(
              TextElement(id: 'missing', transform: box(0, 0), text: '')),
          item,
        ),
        isTrue,
      );
    });
  });

  group('StoryDocument', () {
    final document = sampleDocument();

    test('locates groups, items, and assets', () {
      expect(document.groupById('g2')?.items, hasLength(2));
      expect(document.groupById('nope'), isNull);
      const location = StoryItemLocation(groupIndex: 1, itemIndex: 0);
      expect(document.locateItem('i3'), location);
      expect(document.itemAt(location)?.id, 'i3');
      expect(
        document.itemAt(const StoryItemLocation(groupIndex: 5, itemIndex: 0)),
        isNull,
      );
      expect(document.allItems.map((i) => i.id), ['i1', 'i2', 'i3', 'i4']);
      expect(document.assetById('hero')?.type, StoryAssetType.image);
    });

    test('resolves asset references', () {
      expect(
        document.resolveSource(const ReferenceStorySource('hero')),
        NetworkStorySource(Uri.parse('https://cdn.example.com/a.jpg')),
      );
      const file = FileStorySource('/x');
      expect(identical(document.resolveSource(file), file), isTrue);
      expect(
        () => document.resolveSource(const ReferenceStorySource('missing')),
        throwsA(
            isA<StoryNotFoundException>().having((e) => e.id, 'id', 'missing')),
      );
    });

    test('groups expire at their expiry time', () {
      final group = document.groups.first;
      expect(group.isExpiredAt(DateTime.utc(2026, 1, 1, 12)), isFalse);
      expect(group.isExpiredAt(DateTime.utc(2026, 1, 2)), isTrue);
      expect(document.groups[1].isExpiredAt(DateTime.utc(3000)), isFalse);
    });

    test('equal documents compare equal', () {
      expect(sampleDocument(), sampleDocument());
      expect(sampleDocument().hashCode, sampleDocument().hashCode);
      expect(sampleDocument(), isNot(document.copyWith(revision: 4)));
    });

    test('canvas presets expose geometry', () {
      const canvas = StoryCanvasConfiguration(
        width: 100,
        height: 200,
        safeArea: StoryInsets.only(top: 10, bottom: 20),
      );
      expect(canvas.aspectRatio, 0.5);
      expect(canvas.safeBounds, const StoryRect.fromLTWH(0, 10, 100, 170));
      expect(
          StoryCanvasConfiguration.portrait.size, const StorySize(1080, 1920));
    });
  });
}
