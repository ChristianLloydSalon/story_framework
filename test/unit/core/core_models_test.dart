import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/composition.dart';

void main() {
  group('geometry', () {
    test('points support arithmetic and value equality', () {
      const a = StoryPoint(1, 2);
      expect(a + const StoryPoint(3, 4), const StoryPoint(4, 6));
      expect(a - const StoryPoint(1, 1), const StoryPoint(0, 1));
      expect(a * 2, const StoryPoint(2, 4));
      expect(a.hashCode, const StoryPoint(1, 2).hashCode);
    });

    test('rect from center derives edges', () {
      final rect = StoryRect.fromCenter(
          const StoryPoint(50, 50), const StorySize(20, 10));
      expect(rect.left, 40);
      expect(rect.top, 45);
      expect(rect.right, 60);
      expect(rect.bottom, 55);
      expect(rect.center, const StoryPoint(50, 50));
      expect(rect.contains(const StoryPoint(41, 46)), isTrue);
      expect(rect.contains(const StoryPoint(61, 46)), isFalse);
    });

    test('size aspect ratio handles zero height', () {
      expect(const StorySize(1080, 1920).aspectRatio, closeTo(0.5625, 1e-9));
      expect(const StorySize(10, 0).aspectRatio, 0);
      expect(StorySize.zero.isEmpty, isTrue);
    });

    test('insets validity', () {
      expect(const StoryInsets.all(4).isValid, isTrue);
      expect(const StoryInsets.only(left: -1).isValid, isFalse);
    });
  });

  group('StoryColor', () {
    test('packs and unpacks channels', () {
      const color = StoryColor.fromARGB(0x80, 0x11, 0x22, 0x33);
      expect(color.value, 0x80112233);
      expect(color.alpha, 0x80);
      expect(color.red, 0x11);
      expect(color.green, 0x22);
      expect(color.blue, 0x33);
      expect(color.withAlpha(0xFF).value, 0xFF112233);
    });

    test('round-trips through hex', () {
      const color = StoryColor(0x0A0B0C0D);
      expect(color.toHex(), '#0A0B0C0D');
      expect(StoryColor.parse(color.toHex()), color);
      expect(StoryColor.parse('#FF8800'), const StoryColor(0xFFFF8800));
      expect(StoryColor.parse('ff8800'), const StoryColor(0xFFFF8800));
    });

    test('rejects malformed hex', () {
      expect(() => StoryColor.parse('#12345'), throwsFormatException);
      expect(() => StoryColor.parse('#GGGGGG'), throwsFormatException);
    });
  });

  group('JSON utilities', () {
    test('isJsonCompatible accepts JSON values only', () {
      expect(
        isJsonCompatible({
          'a': [1, 2.5, 'x', null, true],
          'b': {'c': <String, Object?>{}},
        }),
        isTrue,
      );
      expect(isJsonCompatible(double.nan), isFalse);
      expect(isJsonCompatible({1: 'x'}), isFalse);
      expect(isJsonCompatible(DateTime(2020)), isFalse);
    });

    test('model maps are deeply frozen', () {
      final source = <String, Object?>{
        'list': [1, 2],
        'map': {'k': 'v'},
      };
      final element = CustomElement(
        id: 'c',
        transform: const StoryTransform(
            position: StoryPoint.zero, size: StorySize.zero),
        customType: 't',
        data: source,
      );
      source['list'] = 'mutated';
      expect(element.data['list'], [1, 2]);
      expect(() => element.data['x'] = 1, throwsUnsupportedError);
      expect(() => (element.data['list']! as List<Object?>).add(3),
          throwsUnsupportedError);
      expect(
        () => (element.data['map']! as Map<String, Object?>)['k'] = 'w',
        throwsUnsupportedError,
      );
    });

    test('non-JSON custom data is rejected early', () {
      expect(
        () => StoryDocument(id: 'd', customData: {'when': DateTime(2020)}),
        throwsArgumentError,
      );
    });
  });

  group('StorySource', () {
    test('network toString hides query parameters', () {
      final source = NetworkStorySource(
          Uri.parse('https://cdn.example.com/a.mp4?token=secret#t=1'));
      expect(source.toString(), isNot(contains('secret')));
      expect(source.toString(), contains('cdn.example.com/a.mp4'));
    });

    test('memory sources copy and freeze their bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final source = MemoryStorySource(bytes);
      bytes[0] = 9;
      expect(source.bytes[0], 1);
      expect(() => source.bytes[0] = 5, throwsUnsupportedError);
      expect(source, MemoryStorySource(Uint8List.fromList([1, 2, 3])));
    });

    test('stream sources are not serializable', () {
      final source = StreamStorySource(() => const Stream.empty());
      expect(source.isSerializable, isFalse);
      expect(const FileStorySource('/a').isSerializable, isTrue);
    });
  });

  group('StoryPlaybackState', () {
    test('progress is clamped and safe for unknown durations', () {
      expect(StoryPlaybackState.initial().progress, 0);
      final halfway = StoryPlaybackState(
        position: const Duration(seconds: 2),
        duration: const Duration(seconds: 4),
      );
      expect(halfway.progress, 0.5);
      expect(
        halfway.copyWith(position: const Duration(seconds: 9)).progress,
        1,
      );
      expect(halfway.copyWith(clearDuration: true).progress, 0);
    });

    test('pause reasons are immutable and compared by value', () {
      final reasons = {StoryPauseReason.user};
      final state = StoryPlaybackState(pauseReasons: reasons);
      reasons.add(StoryPauseReason.modal);
      expect(state.pauseReasons, {StoryPauseReason.user});
      expect(state.isHeld, isTrue);
      expect(
        () => state.pauseReasons.add(StoryPauseReason.buffering),
        throwsUnsupportedError,
      );
      expect(state, StoryPlaybackState(pauseReasons: {StoryPauseReason.user}));
    });
  });

  group('exceptions', () {
    test('invalid composition summarises the first error', () {
      final exception = InvalidCompositionException([
        const StoryValidationIssue.warning('w', 'just a warning', path: 'a'),
        const StoryValidationIssue.error('e1', 'first', path: 'b'),
        const StoryValidationIssue.error('e2', 'second', path: 'c'),
      ]);
      expect(exception.message, 'Invalid composition: first at b and 1 more');
      expect(exception, isA<StoryException>());
    });

    test('serialization errors include their path', () {
      const exception = SerializationException('bad', path: 'groups[0].id');
      expect(exception.toString(), contains('at groups[0].id'));
    });
  });
}
