import 'package:story_framework/story_framework.dart';

/// Stories built entirely from text, shapes, stickers, and drawings, so the
/// example runs offline with no assets.
StoryDocument sampleDocument() {
  return StoryDocument(
    id: 'example',
    title: 'Example stories',
    groups: [
      StoryGroup(
        id: 'ada',
        title: 'Ada',
        items: [
          _titleCard(
            id: 'ada-1',
            colors: const [StoryColor(0xFF6A11CB), StoryColor(0xFF2575FC)],
            headline: 'Hello from\nStory Framework',
            caption: 'Everything here is a StoryDocument.',
          ),
          StoryItem(
            id: 'ada-2',
            background: StoryGradientBackground(
              colors: const [StoryColor(0xFFFF512F), StoryColor(0xFFDD2476)],
            ),
            elements: [
              _text('ada-2-text', 'Stickers, shapes\nand drawings', y: 520),
              StickerElement(
                id: 'ada-2-party',
                transform: _box(300, 1000, 260, 260, rotation: -0.2),
                sticker: const EmojiSticker('🎉'),
                semanticLabel: 'Party popper',
              ),
              StickerElement(
                id: 'ada-2-rocket',
                transform: _box(780, 1150, 220, 220, rotation: 0.3),
                sticker: const EmojiSticker('🚀'),
                semanticLabel: 'Rocket',
              ),
              ShapeElement(
                id: 'ada-2-ring',
                transform: _box(540, 1500, 420, 420),
                shape: StoryShapeType.ellipse,
                stroke: const StoryStroke(color: StoryColor.white, width: 14),
              ),
              DrawingElement(
                id: 'ada-2-scribble',
                transform: _box(540, 1500, 420, 420),
                strokes: [
                  StoryDrawingStroke(
                    color: const StoryColor(0xFFFFEB3B),
                    width: 18,
                    points: const [
                      StoryPoint(90, 230),
                      StoryPoint(170, 300),
                      StoryPoint(330, 130),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      StoryGroup(
        id: 'grace',
        title: 'Grace',
        items: [
          _titleCard(
            id: 'grace-1',
            colors: const [StoryColor(0xFF11998E), StoryColor(0xFF38EF7D)],
            headline: 'Swipe left\nfor the next person',
            caption: 'Or keep tapping.',
          ),
          _titleCard(
            id: 'grace-2',
            colors: const [StoryColor(0xFF232526), StoryColor(0xFF414345)],
            headline: 'Hold to pause',
            caption: 'Playback resumes when you let go.',
          ),
          StoryItem(
            id: 'grace-poll',
            duration: const FixedItemDuration(Duration(seconds: 10)),
            background: StoryGradientBackground(
              colors: const [StoryColor(0xFF8E2DE2), StoryColor(0xFF4A00E0)],
            ),
            elements: [
              InteractiveElement(
                id: 'grace-poll-sticker',
                transform: _box(540, 860, 860, 560),
                interaction: StoryPoll(
                  question: 'Tabs or spaces?',
                  choices: const [
                    StoryChoice(id: 'tabs', label: 'Tabs'),
                    StoryChoice(id: 'spaces', label: 'Spaces'),
                  ],
                ),
              ),
              InteractiveElement(
                id: 'grace-link',
                transform: _box(540, 1350, 700, 160),
                interaction: StoryLink(
                  url: Uri.parse('https://pub.dev/packages/story_framework'),
                  label: 'View the package',
                ),
              ),
            ],
          ),
          StoryItem(
            id: 'grace-video',
            // Lasts as long as the clip, at most 10 seconds; 6 seconds if the
            // clip cannot load.
            duration: const MediaItemDuration(
              elementId: 'grace-video-clip',
              maxDuration: Duration(seconds: 10),
              fallback: Duration(seconds: 6),
            ),
            elements: [
              VideoElement(
                id: 'grace-video-clip',
                transform: _box(540, 960, 1080, 1920),
                source: NetworkStorySource(Uri.parse(
                    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4')),
                muted: true,
              ),
              _text('grace-video-caption', 'Video stories', y: 1600),
            ],
          ),
          _titleCard(
            id: 'grace-3',
            colors: const [StoryColor(0xFFF7971E), StoryColor(0xFFFFD200)],
            headline: 'That’s all!',
            caption: 'Swipe down to close.',
          ),
        ],
      ),
    ],
  );
}

StoryItem _titleCard({
  required String id,
  required List<StoryColor> colors,
  required String headline,
  required String caption,
}) {
  return StoryItem(
    id: id,
    background: StoryGradientBackground(colors: colors),
    elements: [
      _text('$id-headline', headline, y: 860, size: 96, weight: 800),
      _text('$id-caption', caption, y: 1120, size: 48, weight: 400),
    ],
  );
}

TextElement _text(
  String id,
  String text, {
  required double y,
  double size = 80,
  int weight = 700,
}) {
  return TextElement(
    id: id,
    transform: _box(540, y, 960, size * 3.2),
    text: text,
    style: StoryTextStyle(
      fontSize: size,
      fontWeight: weight,
      lineHeight: 1.1,
      shadows: const [
        StoryShadow(offset: StoryPoint(0, 4), blurRadius: 12),
      ],
    ),
  );
}

StoryTransform _box(
  double x,
  double y,
  double width,
  double height, {
  double rotation = 0,
}) {
  return StoryTransform(
    position: StoryPoint(x, y),
    size: StorySize(width, height),
    rotation: rotation,
  );
}
