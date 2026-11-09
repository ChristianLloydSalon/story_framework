import 'dart:typed_data';

import 'package:story_framework/composition.dart';

StoryTransform box(double x, double y, [double w = 100, double h = 100]) =>
    StoryTransform(position: StoryPoint(x, y), size: StorySize(w, h));

/// A document exercising every element, source, background, and duration
/// kind, used for round-trip and validation tests.
StoryDocument sampleDocument() {
  return StoryDocument(
    id: 'doc-1',
    title: 'Sample',
    revision: 3,
    canvas: const StoryCanvasConfiguration(
      width: 1080,
      height: 1920,
      background: StoryColorBackground(StoryColor(0xFF101010)),
      safeArea: StoryInsets.only(top: 120, bottom: 80),
      scalingBehavior: StoryScalingBehavior.cover,
    ),
    assets: [
      StoryAsset(
        id: 'hero',
        type: StoryAssetType.image,
        source: NetworkStorySource(Uri.parse('https://cdn.example.com/a.jpg')),
        mimeType: 'image/jpeg',
        metadata: const {'width': 1080},
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    updatedAt: DateTime.utc(2026, 1, 3),
    metadata: const {'app': 'tests'},
    customData: const {
      'tags': ['a', 'b'],
      'nested': {'x': 1.5, 'flag': true, 'none': null},
    },
    groups: [
      StoryGroup(
        id: 'g1',
        title: 'Alice',
        createdAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2026, 1, 2),
        items: [
          StoryItem(
            id: 'i1',
            duration: const FixedItemDuration(Duration(seconds: 5)),
            transition: StoryTransitionConfiguration(
              type: 'fade',
              duration: const Duration(milliseconds: 250),
              curve: 'linear',
              parameters: const {'from': 0.2},
            ),
            playback: const StoryItemPlaybackConfiguration(autoAdvance: false),
            background: StoryGradientBackground(
              colors: const [StoryColor.black, StoryColor.white],
              stops: const [0, 1],
            ),
            elements: [
              ImageElement(
                id: 'img',
                transform: box(540, 960, 1080, 1920),
                source: const ReferenceStorySource('hero'),
                fit: StoryFit.contain,
                semanticLabel: 'A beach',
              ),
              TextElement(
                id: 'txt',
                transform: const StoryTransform(
                  position: StoryPoint(540, 300),
                  size: StorySize(800, 200),
                  rotation: 0.25,
                  scale: 1.5,
                  flipHorizontal: true,
                ),
                text: 'Hello',
                style: StoryTextStyle(
                  fontFamily: 'Inter',
                  fontSize: 64,
                  fontWeight: 700,
                  italic: true,
                  color: const StoryColor(0xFFFFCC00),
                  lineHeight: 1.2,
                  letterSpacing: 1,
                  shadows: const [
                    StoryShadow(offset: StoryPoint(2, 2), blurRadius: 4),
                  ],
                  stroke: const StoryStroke(color: StoryColor.black, width: 2),
                ),
                align: StoryTextAlign.left,
                backgroundColor: const StoryColor(0x80000000),
                padding: const StoryInsets.all(12),
                zIndex: 2,
              ),
              StickerElement(
                id: 'emoji',
                transform: box(100, 100),
                sticker: const EmojiSticker('🎉'),
                opacity: 0.5,
                locked: true,
              ),
              StickerElement(
                id: 'gif',
                transform: box(200, 200),
                sticker: const ImageSticker(
                  AssetStorySource('stickers/cat.gif', package: 'pack'),
                  animated: true,
                ),
              ),
              StickerElement(
                id: 'provided',
                transform: box(300, 300),
                sticker: CustomSticker(
                  providerId: 'giphy',
                  stickerId: 'abc',
                  data: const {'rating': 'g'},
                ),
              ),
              ShapeElement(
                id: 'shape',
                transform: box(500, 500),
                shape: StoryShapeType.ellipse,
                fillColor: const StoryColor(0xFF00FF00),
                stroke: const StoryStroke(color: StoryColor.white, width: 3),
                cornerRadius: 8,
                visible: false,
              ),
              DrawingElement(
                id: 'draw',
                transform: box(540, 960, 1080, 1920),
                strokes: [
                  StoryDrawingStroke(
                    points: const [StoryPoint(0, 0), StoryPoint(10.5, 20)],
                    color: const StoryColor(0xFFFF0000),
                    width: 6,
                    opacity: 0.8,
                    tool: StoryDrawingTool.marker,
                  ),
                ],
              ),
              WidgetElement(
                id: 'poll',
                transform: box(540, 1500, 800, 300),
                widgetType: 'poll',
                data: const {
                  'question': 'Tea?',
                  'options': ['Yes', 'No'],
                },
              ),
              CustomElement(
                id: 'map',
                transform: box(540, 1200),
                customType: 'map',
                data: const {'lat': 1.0, 'lng': 2.0},
                metadata: const {'tool': 'map'},
                customData: const {'pinned': true},
              ),
            ],
          ),
          StoryItem(
            id: 'i2',
            duration: const MediaItemDuration(
              elementId: 'vid',
              maxDuration: Duration(seconds: 30),
              fallback: Duration(seconds: 10),
            ),
            background: const StoryMediaBackground(
              FileStorySource('/tmp/bg.png'),
              fit: StoryFit.fill,
            ),
            elements: [
              VideoElement(
                id: 'vid',
                transform: box(540, 960, 1080, 1920),
                source: const FileStorySource('/tmp/clip.mp4'),
                volume: 0.7,
                muted: true,
                loop: true,
                trimStart: const Duration(milliseconds: 500),
                trimEnd: const Duration(seconds: 12),
              ),
              AudioElement(
                id: 'music',
                source: CustomStorySource('spotify', data: const {'id': 'x'}),
                volume: 0.3,
              ),
            ],
          ),
        ],
      ),
      StoryGroup(
        id: 'g2',
        items: [
          StoryItem(
            id: 'i3',
            duration: const IndefiniteItemDuration(),
            elements: [
              ImageElement(
                id: 'mem',
                transform: box(10, 10),
                source: MemoryStorySource(
                  Uint8List.fromList([1, 2, 3, 250]),
                  mimeType: 'image/png',
                ),
              ),
            ],
          ),
          StoryItem(
            id: 'i4',
            duration: CustomItemDuration('quiz', data: const {'max': 3}),
          ),
        ],
      ),
    ],
  );
}
