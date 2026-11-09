// Renders the README screenshots into doc/screenshots/.
//
// Not part of the test suite. Run on Windows (it loads the Segoe UI font so
// text renders with real glyphs):
//
//   flutter test tool/screenshots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/story_framework.dart';

import '../test/helpers/engine_fakes.dart';

const String _font = 'Shot';

Future<void> _loadFonts() async {
  final loader = FontLoader(_font);
  for (final file in [
    'segoeui.ttf',
    'segoeuib.ttf',
    'seguisym.ttf',
    'seguiemj.ttf'
  ]) {
    final path = 'C:/Windows/Fonts/$file';
    if (File(path).existsSync()) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
  }
  await loader.load();
  // Widgets without an explicit family fall back to "Roboto" in tests.
  final fallback = FontLoader('Roboto');
  for (final file in [
    'segoeui.ttf',
    'segoeuib.ttf',
    'seguisym.ttf',
    'seguiemj.ttf'
  ]) {
    final path = 'C:/Windows/Fonts/$file';
    if (File(path).existsSync()) {
      fallback.addFont(
          Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    }
  }
  await fallback.load();
  // Arrows and geometric symbols live in separate fonts on Windows.
  final symbols = FontLoader('Symbols');
  for (final file in ['seguisym.ttf', 'cambria.ttc', 'seguiemj.ttf']) {
    final path = 'C:/Windows/Fonts/$file';
    if (File(path).existsSync()) {
      symbols.addFont(
          Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    }
  }
  await symbols.load();
}

StoryTransform _box(double x, double y, double w, double h) =>
    StoryTransform(position: StoryPoint(x, y), size: StorySize(w, h));

TextElement _text(String id, String text, double y,
        {double size = 88, int weight = 800}) =>
    TextElement(
      id: id,
      transform: _box(540, y, 960, size * 3),
      text: text,
      style: StoryTextStyle(
        fontFamily: _font,
        fontSize: size,
        fontWeight: weight,
        lineHeight: 1.1,
        shadows: const [StoryShadow(offset: StoryPoint(0, 4), blurRadius: 12)],
      ),
    );

StoryDocument showcase() => StoryDocument(id: 'showcase', groups: [
      StoryGroup(id: 'ada', title: 'Ada Lovelace', items: [
        StoryItem(
          id: 'welcome',
          background: StoryGradientBackground(colors: const [
            StoryColor(0xFF6A11CB),
            StoryColor(0xFF2575FC),
          ]),
          elements: [
            _text('t1', 'Stories,\nyour way', 820, size: 120),
            _text('t2', 'Viewer · Editor · Export', 1120,
                size: 52, weight: 500),
            ShapeElement(
              id: 'ring',
              transform: _box(540, 1500, 360, 360),
              shape: StoryShapeType.ellipse,
              stroke: const StoryStroke(color: StoryColor.white, width: 16),
            ),
            DrawingElement(
              id: 'tick',
              transform: _box(540, 1500, 360, 360),
              strokes: [
                StoryDrawingStroke(
                  color: const StoryColor(0xFFFFEB3B),
                  width: 26,
                  points: const [
                    StoryPoint(90, 190),
                    StoryPoint(160, 260),
                    StoryPoint(280, 110),
                  ],
                ),
              ],
            ),
          ],
        ),
        StoryItem(
          id: 'poll',
          background: StoryGradientBackground(colors: const [
            StoryColor(0xFFFF512F),
            StoryColor(0xFFDD2476),
          ]),
          elements: [
            _text('p-title', 'Interactive stickers', 420, size: 76),
            InteractiveElement(
              id: 'poll-sticker',
              transform: _box(540, 960, 880, 560),
              interaction:
                  StoryPoll(question: 'Tabs or spaces?', choices: const [
                StoryChoice(id: 'tabs', label: 'Tabs'),
                StoryChoice(id: 'spaces', label: 'Spaces'),
              ]),
            ),
            InteractiveElement(
              id: 'link',
              transform: _box(540, 1450, 700, 160),
              interaction: StoryLink(
                url: Uri.parse('https://pub.dev/packages/story_framework'),
                label: 'View the package',
              ),
            ),
          ],
        ),
      ]),
    ]);

class _Frame extends StatelessWidget {
  const _Frame({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(
                fontFamily: _font, fontFamilyFallback: ['Symbols']),
            child: RepaintBoundary(child: child),
          ),
        ),
      );
}

void main() {
  setUpAll(_loadFonts);

  Future<StoryController> viewer(WidgetTester tester,
      {required String startAt,
      StoryInteractionController? interactions}) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final document = showcase();
    final harness = EngineHarness();
    final controller = StoryController(
      document: document,
      clock: harness.clock,
      tickerFactory: harness.createTicker,
      initialLocation: document.locateItem(startAt),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_Frame(
      size: const Size(360, 720),
      child: StoryViewer.controller(
        controller: controller,
        interactionController: interactions,
        config: const StoryViewerConfig(layout: StoryViewerLayout.inline),
        onDismiss: () {},
      ),
    ));
    await tester.pump();
    harness.advance(const Duration(milliseconds: 2200));
    await tester.pump();
    return controller;
  }

  testWidgets('viewer', (tester) async {
    await viewer(tester, startAt: 'welcome');
    await expectLater(find.byType(RepaintBoundary).first,
        matchesGoldenFile('../doc/screenshots/viewer.png'));
  });

  testWidgets('interactive', (tester) async {
    final interactions = StoryInteractionController(initialStates: {
      'poll-sticker': StoryChoiceState(
          selectedChoiceId: 'spaces', counts: const {'tabs': 38, 'spaces': 62}),
    });
    addTearDown(interactions.dispose);
    await viewer(tester, startAt: 'poll', interactions: interactions);
    await expectLater(find.byType(RepaintBoundary).first,
        matchesGoldenFile('../doc/screenshots/interactive.png'));
  });

  testWidgets('editor', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final editor = StoryEditorController(
      document: showcase(),
      idGenerator: SequentialStoryIdGenerator(),
    );
    addTearDown(editor.dispose);
    editor.select(['t1']);
    await tester.pumpWidget(_Frame(
      size: const Size(1280, 800),
      child: StoryEditor(controller: editor),
    ));
    await tester.pump();
    await expectLater(find.byType(RepaintBoundary).first,
        matchesGoldenFile('../doc/screenshots/editor.png'));
  });
}
