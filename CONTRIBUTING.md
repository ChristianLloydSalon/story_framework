# Contributing

## Setup

Requires the Flutter stable SDK.

```bash
flutter pub get
```

## Before opening a pull request

```bash
dart format .
flutter analyze
flutter test
```

CI runs the same checks plus `flutter pub publish --dry-run`.

## Guidelines

- Read [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) for module boundaries and
  dependency rules, and [doc/API_DESIGN.md](doc/API_DESIGN.md) for naming
  and API conventions.
- Every public member needs a doc comment (`public_member_api_docs` is on).
- New behavior needs tests. Use fakes and deterministic fixtures; avoid real
  timers and network access in unit tests.
- Do not add a dependency until the feature that needs it is being built.
- Changes to the serialized format must bump
  `StoryDocumentCodec.currentSchemaVersion` and ship a migration.
- Update `CHANGELOG.md` under the next unreleased version.
