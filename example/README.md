# Story Framework examples

Ten runnable examples, from basic to advanced, plus a story tray showcase.

This folder has no platform directories, to keep the repository small.
Generate the ones you need first:

```bash
flutter create . --platforms=android,ios,web
```

Run the whole app (story tray plus a list of every example):

```bash
flutter run
```

Or run a single example on its own:

| # | Example | Run | Needs network |
|---|---|---|---|
| 1 | Basic story | `flutter run -t lib/examples/01_basic_story/main.dart` | |
| 2 | Images and transitions | `flutter run -t lib/examples/02_images_and_transitions/main.dart` | ✓ |
| 3 | Customized viewer (header, footer, overlays, speed) | `flutter run -t lib/examples/03_custom_viewer/main.dart` | |
| 4 | Interactive stickers | `flutter run -t lib/examples/04_interactive_stickers/main.dart` | |
| 5 | Video and audio | `flutter run -t lib/examples/05_video_and_audio/main.dart` | ✓ |
| 6 | Story editor | `flutter run -t lib/examples/06_story_editor/main.dart` | |
| 7 | Save, load, and validate | `flutter run -t lib/examples/07_save_load_validate/main.dart` | |
| 8 | Export to PNG and JSON | `flutter run -t lib/examples/08_export/main.dart` | |
| 9 | Headless playback (custom player) | `flutter run -t lib/examples/09_headless_playback/main.dart` | |
| 10 | Custom element and renderer | `flutter run -t lib/examples/10_custom_renderer/main.dart` | |

Each folder's `main.dart` holds the whole example. Shared helpers are in
`lib/examples/shared.dart`.

`lib/media/` holds ready-made adapters for `video_player` and `just_audio`.
story_framework itself has no player dependency; copy these into your app.

Run the tests with `flutter test`. They open every example that works
offline.
