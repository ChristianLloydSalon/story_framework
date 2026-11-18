import 'package:story_framework/story_framework.dart';

/// The document the playground opens with: text, stickers, and shapes only,
/// so it needs no assets or network.
StoryDocument seedDocument() => StoryDocument(
      id: 'playground',
      title: 'Playground',
      groups: [
        StoryGroup(
          id: 'you',
          title: 'You',
          items: [
            StoryItem(
              id: 'welcome',
              background: StoryGradientBackground(
                colors: const [StoryColor(0xFF6A11CB), StoryColor(0xFF2575FC)],
              ),
              elements: [
                _text('welcome-title', 'Story Framework\nPlayground',
                    y: 760, size: 104, weight: 800),
                _text(
                  'welcome-caption',
                  'Edit on the left.\nThe preview plays your draft.',
                  y: 1120,
                  size: 56,
                  weight: 500,
                ),
              ],
            ),
            StoryItem(
              id: 'stickers',
              background: StoryGradientBackground(
                colors: const [StoryColor(0xFFFF512F), StoryColor(0xFFDD2476)],
              ),
              elements: [
                _text('stickers-title', 'Drag, scale,\nand rotate me', y: 520),
                StickerElement(
                  id: 'stickers-party',
                  transform: _box(320, 1050, 260, 260, rotation: -0.2),
                  sticker: const EmojiSticker('🎉'),
                  semanticLabel: 'Party popper',
                ),
                StickerElement(
                  id: 'stickers-rocket',
                  transform: _box(760, 1200, 220, 220, rotation: 0.3),
                  sticker: const EmojiSticker('🚀'),
                  semanticLabel: 'Rocket',
                ),
                ShapeElement(
                  id: 'stickers-ring',
                  transform: _box(540, 1560, 360, 360),
                  shape: StoryShapeType.ellipse,
                  stroke: const StoryStroke(color: StoryColor.white, width: 14),
                ),
              ],
            ),
          ],
        ),
      ],
    );

TextElement _text(
  String id,
  String text, {
  required double y,
  double size = 80,
  int weight = 700,
}) =>
    TextElement(
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

StoryTransform _box(
  double x,
  double y,
  double width,
  double height, {
  double rotation = 0,
}) =>
    StoryTransform(
      position: StoryPoint(x, y),
      size: StorySize(width, height),
      rotation: rotation,
    );
