# Story Framework example

A story tray and full-screen viewer, built from text, gradients, stickers,
shapes, and drawings. It needs no network or assets.

This folder has no platform directories, to keep the repository small.
Generate the ones you need, then run:

```bash
flutter create . --platforms=android,ios,web
flutter run
```

Run the smoke test with `flutter test`.

`lib/media/` holds ready-made adapters for `video_player` and `just_audio`.
story_framework itself has no player dependency; copy these into your app.
