import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

/// One runnable example: a title, what it shows, and the page that shows it.
class StoryExample {
  const StoryExample({
    required this.number,
    required this.title,
    required this.description,
    required this.page,
  });

  final int number;
  final String title;
  final String description;
  final Widget page;
}

/// A standalone app for a single example, used by each example's `main.dart`.
class ExampleApp extends StatelessWidget {
  const ExampleApp({required this.example, super.key});

  final StoryExample example;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: example.title,
        debugShowCheckedModeBanner: false,
        theme: exampleTheme,
        home: ExampleLauncherPage(example: example),
      );
}

/// The theme shared by every example.
final ThemeData exampleTheme = ThemeData(
  colorSchemeSeed: Colors.deepPurple,
  useMaterial3: true,
);

/// Describes an example and opens it.
class ExampleLauncherPage extends StatelessWidget {
  const ExampleLauncherPage({required this.example, super.key});

  final StoryExample example;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${example.number}. ${example.title}')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(example.description,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => openExample(context, example),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Open'),
              ),
            ],
          ),
        ),
      );
}

/// Pushes [example]'s page full screen.
void openExample(BuildContext context, StoryExample example) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => example.page,
    ),
  );
}

/// A black full-screen page around a viewer.
class StoryPageFrame extends StatelessWidget {
  const StoryPageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Colors.black, body: child);
}

// Document helpers: canvas units on the default 1080×1920 canvas.

/// A box centered at ([x], [y]).
StoryTransform box(double x, double y, double width, double height) =>
    StoryTransform(
      position: StoryPoint(x, y),
      size: StorySize(width, height),
    );

/// A full-canvas box.
const StoryTransform fullCanvas = StoryTransform(
  position: StoryPoint(540, 960),
  size: StorySize(1080, 1920),
);

/// Centered white text with a soft shadow.
TextElement title(String id, String text,
        {double y = 960, double size = 96, int weight = 800}) =>
    TextElement(
      id: id,
      transform: box(540, y, 960, size * 3),
      text: text,
      zIndex: 10,
      style: StoryTextStyle(
        fontSize: size,
        fontWeight: weight,
        lineHeight: 1.1,
        shadows: const [
          StoryShadow(offset: StoryPoint(0, 4), blurRadius: 12),
        ],
      ),
    );

/// A two-color vertical gradient.
StoryGradientBackground gradient(int top, int bottom) =>
    StoryGradientBackground(colors: [StoryColor(top), StoryColor(bottom)]);
