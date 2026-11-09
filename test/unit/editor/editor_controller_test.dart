import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/editor.dart';

import '../../helpers/editor_fixtures.dart';

void main() {
  group('document edits', () {
    test('update, insert, remove, and move items share unchanged data', () {
      final document = editorDoc();
      final edited = document.updateItem(
          'b', (item) => item.copyWith(metadata: const {'x': 1}));
      expect(edited.itemById('b')?.metadata, {'x': 1});
      expect(identical(edited.itemById('a'), document.itemById('a')), isTrue,
          reason: 'structural sharing');
      expect(identical(edited.groups[1], document.groups[1]), isTrue);

      final moved = document.moveItem('a', toGroupId: 'g2', toIndex: 1);
      expect(moved.groups[0].items.map((i) => i.id), ['b']);
      expect(moved.groups[1].items.map((i) => i.id), ['c', 'a']);
      expect(document.removeItem('b').allItems.map((i) => i.id), ['a', 'c']);
      expect(() => document.removeItem('zzz'),
          throwsA(isA<StoryNotFoundException>()));
    });

    test('layer reordering normalizes z-indexes to list order', () {
      final item = StoryItem(id: 'i', elements: [
        textAt('x', 0, 0, zIndex: 5),
        textAt('y', 0, 0),
        textAt('z', 0, 0, zIndex: 2),
      ]);
      final reordered = item.reorderLayers(['x', 'y']);
      expect(reordered.elements.map((e) => e.id), ['z', 'x', 'y']);
      expect(reordered.elements.map((e) => e.zIndex), [0, 1, 2]);
      expect(() => item.insertElement(textAt('x', 0, 0)),
          throwsA(isA<EditorOperationException>()));
    });
  });

  group('history', () {
    test('every edit is one labeled undo step', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1']);
      editor.moveSelection(const StoryPoint(10, 0));
      editor.deleteSelection();
      expect(editor.undoLabel, 'Delete');
      editor.undo();
      expect(editor.elementById('t1')?.transform.position,
          const StoryPoint(210, 200));
      expect(editor.selection.elementIds, ['t1'], reason: 'selection restored');
      editor.undo();
      expect(editor.elementById('t1')?.transform.position,
          const StoryPoint(200, 200));
      expect(editor.canUndo, isFalse);
      editor.redo();
      editor.redo();
      expect(editor.elementById('t1'), isNull);
      expect(editor.canRedo, isFalse);
    });

    test('a new edit clears redo, and the limit drops the oldest steps', () {
      final editor = editorFor(editorDoc(),
          config: const StoryEditorConfig(historyLimit: 2));
      editor.select(['t1']);
      for (var i = 0; i < 4; i++) {
        editor.moveSelection(const StoryPoint(1, 0));
      }
      editor
        ..undo()
        ..undo()
        ..undo();
      expect(editor.elementById('t1')?.transform.position.x, 202);
      editor.moveSelection(const StoryPoint(0, 5));
      expect(editor.canRedo, isFalse);
    });

    test('transactions group edits, nest, and can be cancelled', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1']);
      editor.beginTransaction('Drag');
      editor.beginTransaction('Inner');
      editor.moveSelection(const StoryPoint(5, 0));
      editor.commitTransaction(); // inner: no step yet
      editor.moveSelection(const StoryPoint(5, 0));
      expect(editor.canUndo, isFalse);
      editor.commitTransaction();
      expect(editor.undoLabel, 'Drag');
      editor.undo();
      expect(editor.elementById('t1')?.transform.position.x, 200);

      editor.beginTransaction('Oops');
      editor.moveSelection(const StoryPoint(50, 0));
      editor.cancelTransaction();
      expect(editor.elementById('t1')?.transform.position.x, 200);
      expect(editor.canRedo, isTrue, reason: 'cancel leaves history alone');
    });

    test('runTransaction rolls back when the edits throw', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1']);
      expect(
        () => editor.runTransaction('Broken', () {
          editor.moveSelection(const StoryPoint(9, 9));
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(editor.elementById('t1')?.transform.position,
          const StoryPoint(200, 200));
      expect(editor.canUndo, isFalse);
    });

    test('undo commits an open transaction first', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1']);
      editor.beginTransaction('Drag');
      editor.moveSelection(const StoryPoint(5, 0));
      editor.undo();
      expect(editor.isInTransaction, isFalse);
      expect(editor.elementById('t1')?.transform.position.x, 200);
    });

    test('document listeners hear edits, undo, and redo', () {
      final seen = <StoryDocument>[];
      final editor = editorFor(editorDoc(), onChanged: seen.add);
      editor.select(['t1']);
      expect(seen, isEmpty, reason: 'selection is not a document change');
      editor.deleteSelection();
      editor.undo();
      editor.redo();
      expect(seen, hasLength(3));
    });
  });

  group('selection', () {
    test('drops unknown ids and respects locks for edits', () {
      final editor = editorFor(editorDoc(elements: [
        textAt('free', 100, 100),
        textAt('locked', 300, 300, locked: true),
        textAt('hidden', 500, 500, visible: false),
      ]));
      editor.select(['free', 'locked', 'missing']);
      expect(editor.selection.elementIds, ['free', 'locked']);
      editor.moveSelection(const StoryPoint(10, 10));
      expect(editor.elementById('locked')?.transform.position,
          const StoryPoint(300, 300));
      editor.deleteSelection();
      expect(editor.elementById('locked'), isNotNull);

      editor.selectAll();
      expect(editor.selection.elementIds, isEmpty,
          reason: 'locked and hidden are skipped, free was deleted');
    });

    test('toggle and rectangle selection', () {
      final editor = editorFor(editorDoc());
      editor.toggleSelection('t1');
      editor.toggleSelection('t2');
      editor.toggleSelection('t1');
      expect(editor.selection.elementIds, ['t2']);
      editor.selectInRect(StoryRect.fromLTWH(0, 0, 700, 700));
      expect(editor.selection.elementIds, ['t1', 't2']);
    });

    test('switching items clears the selection', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1']);
      editor.setCurrentItem('b');
      expect(editor.selection.isEmpty, isTrue);
      expect(editor.currentItem?.id, 'b');
      expect(() => editor.setCurrentItem('nope'),
          throwsA(isA<StoryNotFoundException>()));
    });
  });

  group('element operations', () {
    test('duplicate creates offset copies with fresh ids, on top', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1', 't2']);
      editor.duplicateSelection();
      final copies = editor.selectedElements;
      expect(copies, hasLength(2));
      expect(copies.map((e) => e.id), everyElement(startsWith('text-')));
      expect(copies.first.transform.position, const StoryPoint(240, 240));
      expect(editor.layerOrder.sublist(3), [for (final c in copies) c.id]);
      expect(editor.undoLabel, 'Duplicate');
      editor.undo();
      expect(editor.currentItem?.elements, hasLength(3));
    });

    test('layer order operations', () {
      final editor = editorFor(editorDoc());
      expect(editor.layerOrder, ['t1', 't2', 't3']);
      editor.select(['t1']);
      editor.bringForward();
      expect(editor.layerOrder, ['t2', 't1', 't3']);
      editor.bringToFront();
      expect(editor.layerOrder, ['t2', 't3', 't1']);
      editor.sendToBack();
      expect(editor.layerOrder, ['t1', 't2', 't3']);
      editor.sendBackward(); // already at the bottom
      expect(editor.undoLabel, 'Send to back');
      editor.reorderLayer('t3', 0);
      expect(editor.layerOrder, ['t3', 't1', 't2']);
      expect(editor.currentItem?.elementsInPaintOrder.map((e) => e.zIndex),
          [0, 1, 2]);
    });

    test('align to each other or to the canvas, and distribute', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1', 't2']);
      editor.alignSelection(StoryAlignment.left);
      expect(editor.elementById('t2')?.transform.position.x, 200);

      editor.select(['t3']);
      editor.alignSelection(StoryAlignment.centerHorizontal);
      expect(editor.elementById('t3')?.transform.position.x, 540);

      final spread = editorFor(editorDoc(elements: [
        textAt('a', 100, 100),
        textAt('b', 150, 100),
        textAt('c', 500, 100),
      ]));
      spread.select(['a', 'b', 'c']);
      spread.distributeSelection(StoryDistribution.horizontal);
      expect(spread.elementById('b')?.transform.position.x, 300);
    });

    test('flip, nudge, rename, visibility, lock', () {
      final editor = editorFor(editorDoc());
      editor.select(['t1']);
      editor.flipSelection(horizontal: true);
      expect(editor.elementById('t1')?.transform.flipHorizontal, isTrue);
      editor.nudgeSelection(1, 0, large: true);
      expect(editor.elementById('t1')?.transform.position.x, 210);
      editor.renameElement('t1', 'Title');
      expect(editor.elementById('t1')?.metadata['name'], 'Title');
      editor.toggleVisible('t1');
      expect(editor.elementById('t1')?.visible, isFalse);
      editor.toggleLocked('t1');
      expect(editor.elementById('t1')?.locked, isTrue);
    });

    test('inline text editing', () {
      final editor = editorFor(editorDoc());
      editor.beginTextEditing('t2');
      expect(editor.editingTextId, 't2');
      expect(editor.selection.elementIds, ['t2']);
      editor.setText('t2', 'Hello');
      expect((editor.elementById('t2') as TextElement).text, 'Hello');
      editor.clearSelection();
      expect(editor.editingTextId, isNull, reason: 'deselecting ends editing');
    });

    test('validation can reject invalid edits', () {
      final editor = editorFor(editorDoc(),
          config:
              const StoryEditorConfig(validation: StoryEditValidation.reject));
      final t1 = editor.elementById('t1');
      expect(t1, isNotNull);
      if (t1 == null) return;
      expect(
        () => editor.updateElement(t1.copyWithCommon(opacity: 3)),
        throwsA(isA<EditorOperationException>()),
      );
      expect(editor.elementById('t1')?.opacity, 1);

      final reporting = editorFor(editorDoc());
      final r1 = reporting.elementById('t1');
      if (r1 == null) return;
      reporting.updateElement(r1.copyWithCommon(opacity: 3));
      expect(reporting.lastValidation?.isValid, isFalse);
    });
  });

  group('items and timeline', () {
    test('add, duplicate, move, and remove items', () {
      final editor = editorFor(editorDoc());
      final added = editor.addItem();
      expect(editor.currentItemId, added);
      expect(editor.currentGroupItems.map((i) => i.id), ['a', added, 'b']);

      editor.setCurrentItem('a');
      final copy = editor.duplicateItem('a');
      final copied = editor.document.itemById(copy);
      expect(copied?.elements.map((e) => e.id),
          everyElement(isNot(anyOf('t1', 't2', 't3'))));
      expect(copied?.elements, hasLength(3));

      editor.moveItem('b', 0);
      expect(editor.currentGroupItems.first.id, 'b');

      editor.removeItem(copy);
      expect(editor.document.itemById(copy), isNull);
      expect(editor.currentItem, isNotNull);

      editor.undo();
      expect(editor.document.itemById(copy), isNotNull);
    });

    test('durations, transitions, and backgrounds can be set and cleared', () {
      final editor = editorFor(editorDoc());
      editor.setItemDuration(
          'a', const FixedItemDuration(Duration(seconds: 8)));
      expect(editor.document.itemById('a')?.duration,
          const FixedItemDuration(Duration(seconds: 8)));
      editor.setItemDuration('a', null);
      expect(editor.document.itemById('a')?.duration, isNull);

      editor.setItemTransition(
          'a', const StoryTransitionConfiguration.preset('fade'));
      expect(editor.document.itemById('a')?.transition?.type, 'fade');
      editor.setItemTransition('a', null);
      expect(editor.document.itemById('a')?.transition, isNull);

      editor.setItemBackground(
          'a', const StoryColorBackground(StoryColor.white));
      expect(editor.document.itemById('a')?.background, isNotNull);
      expect(editor.undoLabel, 'Change background');
    });

    test('media trims can be set and the end cleared', () {
      final editor = editorFor(editorDoc(elements: [
        VideoElement(
          id: 'v',
          transform: boxAt(540, 960, 1080, 1920),
          source: const FileStorySource('/v.mp4'),
          trimEnd: const Duration(seconds: 9),
        ),
      ]));
      editor.setMediaTrim('v', start: const Duration(seconds: 1));
      final video = editor.elementById('v') as VideoElement;
      expect(video.trimStart, const Duration(seconds: 1));
      expect(video.trimEnd, isNull);
    });

    test('groups', () {
      final editor = editorFor(editorDoc());
      final id = editor.addGroup(title: 'New');
      expect(editor.document.groupById(id)?.items, hasLength(1));
      editor.renameGroup(id, 'Renamed');
      expect(editor.document.groupById(id)?.title, 'Renamed');
      editor.removeGroup(id);
      expect(editor.document.groupById(id), isNull);
    });

    test('a blank editor starts with one empty story', () {
      final editor =
          StoryEditorController(idGenerator: SequentialStoryIdGenerator());
      expect(editor.document.allItems, hasLength(1));
      expect(editor.currentItemId, 'item-1');
      editor.dispose();
      expect(editor.selectAll, throwsA(isA<ControllerDisposedException>()));
      expect(editor.undo, throwsA(isA<ControllerDisposedException>()));
    });
  });

  group('geometry', () {
    const rotated = StoryTransform(
      position: StoryPoint(100, 100),
      size: StorySize(200, 20),
      rotation: math.pi / 2,
    );

    test('hit tests follow rotation, scale, and paint order', () {
      expect(StoryElementGeometry.contains(rotated, const StoryPoint(100, 190)),
          isTrue);
      expect(StoryElementGeometry.contains(rotated, const StoryPoint(190, 100)),
          isFalse);
      final item = StoryItem(id: 'i', elements: [
        textAt('bottom', 100, 100),
        textAt('top', 100, 100, zIndex: 1),
        textAt('locked', 100, 100, zIndex: 2, locked: true),
      ]);
      expect(StoryElementGeometry.hitTest(item, const StoryPoint(100, 100))?.id,
          'top');
      expect(
        StoryElementGeometry.hitTest(item, const StoryPoint(100, 100),
                includeLocked: true)
            ?.id,
        'locked',
      );
    });

    test('bounds and local conversion round-trip with flips and scale', () {
      final box = StoryElementGeometry.bounds(rotated);
      expect(box.width, closeTo(20, 1e-9));
      expect(box.height, closeTo(200, 1e-9));
      final transform = rotated.copyWith(scale: 2, flipHorizontal: true);
      const local = StoryPoint(30, 5);
      final canvas = StoryElementGeometry.toCanvas(transform, local);
      final back = StoryElementGeometry.toLocal(transform, canvas);
      expect(back.x, closeTo(local.x, 1e-9));
      expect(back.y, closeTo(local.y, 1e-9));
    });

    test('snapping aligns edges and centers and reports guides', () {
      final result = StorySnapping.snapMove(
        moving: StoryRect.fromLTWH(0, 0, 100, 100),
        delta: const StoryPoint(487, 3),
        targets: [StoryRect.fromLTWH(0, 0, 1080, 1920)],
        threshold: 8,
      );
      expect(result.delta, const StoryPoint(490, 0),
          reason: 'center x snaps to 540, top snaps to 0');
      expect(result.guides, [
        const StoryGuide(StoryGuideAxis.vertical, 540),
        const StoryGuide(StoryGuideAxis.horizontal, 0),
      ]);
      expect(StorySnapping.snapRotation(math.pi / 2 + 0.03),
          closeTo(math.pi / 2, 1e-9));
      expect(StorySnapping.snapRotation(0.3), 0.3);
    });

    test('transform math', () {
      final originals = {'a': boxAt(100, 100), 'b': boxAt(300, 100)};
      final scaled = StoryTransformMath.scaleAround(
          originals, const StoryPoint(200, 100), 2);
      expect(scaled['a']?.position, const StoryPoint(0, 100));
      expect(scaled['b']?.scale, 2);
      final tiny = StoryTransformMath.scaleAround(
          originals, const StoryPoint(200, 100), 0.01,
          minSize: 20);
      expect(tiny['a']?.scale, closeTo(0.2, 1e-9));

      final turned = StoryTransformMath.rotateAround(
          {'a': boxAt(300, 100)}, const StoryPoint(200, 100), math.pi / 2);
      expect(turned['a']?.position.x, closeTo(200, 1e-9));
      expect(turned['a']?.position.y, closeTo(200, 1e-9));
      expect(turned['a']?.rotation, closeTo(math.pi / 2, 1e-9));

      final wider = StoryTransformMath.resizeEdge(boxAt(100, 100),
          horizontal: true,
          start: const StoryPoint(150, 100),
          current: const StoryPoint(170, 100));
      expect(wider.size, const StorySize(140, 100));
    });

    test('viewport mapping round-trips and zooms around the focal point', () {
      const mapping = StoryViewportMapping(
        viewportSize: Size(800, 600),
        canvasSize: StorySize(1080, 1920),
      );
      expect(mapping.fitScale, closeTo(552 / 1920, 1e-9));
      final screen = mapping.toScreen(const StoryPoint(540, 960));
      expect(screen.dx, closeTo(400, 1e-9));
      expect(screen.dy, closeTo(300, 1e-9));
      final back = mapping.toCanvas(screen);
      expect(back.x, closeTo(540, 1e-9));

      const focal = Offset(500, 200);
      final before = mapping.toCanvas(focal);
      final zoomed = StoryViewportMapping(
        viewportSize: mapping.viewportSize,
        canvasSize: mapping.canvasSize,
        viewport: mapping.zoomAround(focal, 2),
      );
      final after = zoomed.toCanvas(focal);
      expect(after.x, closeTo(before.x, 1e-6));
      expect(after.y, closeTo(before.y, 1e-6));
      expect(zoomed.scale, closeTo(mapping.scale * 2, 1e-9));
    });

    test('id generators', () {
      final sequential = SequentialStoryIdGenerator();
      expect([sequential.next('a'), sequential.next('a'), sequential.next('b')],
          ['a-1', 'a-2', 'b-1']);
      final random = RandomStoryIdGenerator(random: math.Random(1));
      expect(random.next('text'), isNot(random.next('text')));
    });
  });
}
