import 'package:flutter/material.dart';
import 'package:story_framework/story_framework.dart';

import '../../media/just_audio_adapter.dart';
import '../../media/video_player_adapter.dart';
import '../shared.dart';

/// Run: flutter run -t lib/examples/05_video_and_audio/main.dart
void main() => runApp(const ExampleApp(example: videoExample));

const videoExample = StoryExample(
  number: 5,
  title: 'Video and audio',
  description: 'A video item that lasts as long as its clip, then a photo '
      'with background music. Players plug in through the adapters in '
      'lib/media/; images use a shared memory cache. Needs an internet '
      'connection.',
  page: VideoPage(),
);

final StoryDocument videoDocument = StoryDocument(
  id: 'video',
  groups: [
    StoryGroup(id: 'media', title: 'Media', items: [
      StoryItem(
        id: 'clip',
        // Lasts as long as the clip (at most 10 s, 6 s if it fails to load).
        duration: const MediaItemDuration(
          elementId: 'clip-video',
          maxDuration: Duration(seconds: 10),
          fallback: Duration(seconds: 6),
        ),
        elements: [
          VideoElement(
            id: 'clip-video',
            transform: fullCanvas,
            source: NetworkStorySource(Uri.parse(
                'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4')),
          ),
          title('clip-title', 'Video stories', y: 1600, size: 80),
        ],
      ),
      StoryItem(
        id: 'music',
        duration: const FixedItemDuration(Duration(seconds: 8)),
        elements: [
          ImageElement(
            id: 'music-photo',
            transform: fullCanvas,
            source: NetworkStorySource(
                Uri.parse('https://picsum.photos/id/1080/1080/1920')),
          ),
          AudioElement(
            id: 'music-track',
            source: NetworkStorySource(Uri.parse(
                'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3')),
            volume: 0.6,
          ),
          title('music-title', 'With music 🎵', y: 1600, size: 80),
        ],
      ),
    ]),
  ],
);

/// Downloads are shared, cancellable, and kept in a 32 MB memory cache.
final StoryResourceLoader imageLoader = StoryResourceLoader(
  fetcher: createStoryHttpFetcher(),
  cache: MemoryStoryCache(maxBytes: 32 * 1024 * 1024),
);

class VideoPage extends StatelessWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return StoryPageFrame(
      child: StoryViewer(
        document: videoDocument,
        mediaFactories: const [
          VideoPlayerStoryMediaFactory(),
          JustAudioStoryMediaFactory(),
        ],
        renderOptions: StoryRenderOptions(
          imageResolver: DefaultStoryImageResolver(networkLoader: imageLoader),
        ),
        onDismiss: navigator.pop,
        onComplete: navigator.pop,
      ),
    );
  }
}
