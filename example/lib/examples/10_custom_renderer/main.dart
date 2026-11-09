import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../shared.dart';

/// Run: flutter run -t lib/examples/10_custom_renderer/main.dart
void main() => runApp(const ExampleApp(example: customRendererExample));

const customRendererExample = StoryExample(
  number: 10,
  title: 'Custom element and renderer',
  description: 'A "confetti" CustomElement drawn by an app-defined '
      'renderer. Register the renderer once and pass the registry to the '
      'viewer, editor, and exporters so the element looks the same '
      'everywhere.',
  page: CustomRendererPage(),
);

final StoryDocument confettiDocument = StoryDocument(
  id: 'confetti',
  groups: [
    StoryGroup(id: 'party', title: 'Party', items: [
      StoryItem(
        id: 'celebrate',
        duration: const FixedItemDuration(Duration(seconds: 8)),
        background: gradient(0xFF0F2027, 0xFF2C5364),
        elements: [
          CustomElement(
            id: 'confetti',
            transform: fullCanvas,
            customType: 'confetti',
            data: const {'count': 90, 'seed': 7},
          ),
          title('celebrate-title', 'We shipped 🎉', size: 110),
        ],
      ),
    ]),
  ],
);

/// Renders `CustomElement`s of type `confetti`.
final class ConfettiRenderer extends StoryElementRenderer<CustomElement> {
  const ConfettiRenderer();

  @override
  String get id => 'confetti';

  @override
  bool supports(StoryElement element) =>
      element is CustomElement && element.customType == 'confetti';

  @override
  Widget buildElement(BuildContext context, CustomElement element,
      StoryRenderContext renderContext) {
    final count = element.data['count'];
    final seed = element.data['seed'];
    return Confetti(
      count: count is int ? count : 60,
      seed: seed is int ? seed : 0,
    );
  }
}

class CustomRendererPage extends StatefulWidget {
  const CustomRendererPage({super.key});

  @override
  State<CustomRendererPage> createState() => _CustomRendererPageState();
}

class _CustomRendererPageState extends State<CustomRendererPage> {
  final StoryRendererRegistry _renderers =
      StoryRendererRegistry.withDefaults([const ConfettiRenderer()]);

  @override
  void dispose() {
    _renderers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return StoryPageFrame(
      child: StoryViewer(
        document: confettiDocument,
        registry: _renderers,
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}

/// Falling confetti pieces.
class Confetti extends StatefulWidget {
  const Confetti({required this.count, required this.seed, super.key});

  final int count;
  final int seed;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  AnimationController? _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    if (animation == null) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: ConfettiPainter(
        animation: animation,
        count: widget.count,
        seed: widget.seed,
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  ConfettiPainter({
    required this.animation,
    required this.count,
    required this.seed,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final int count;
  final int seed;

  static const List<Color> _colors = [
    Color(0xFFFF5252),
    Color(0xFFFFD740),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFE040FB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final offset = random.nextDouble();
      final spin = random.nextDouble() * math.pi * 2;
      final t = (animation.value + offset) % 1;
      final y = t * (size.height + 40) - 20;
      final sway = math.sin(t * math.pi * 4 + spin) * 12;
      paint.color = _colors[i % _colors.length];
      canvas
        ..save()
        ..translate(x + sway, y)
        ..rotate(spin + t * math.pi * 6)
        ..drawRect(const Rect.fromLTWH(-5, -3, 10, 6), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.seed != seed;
}
