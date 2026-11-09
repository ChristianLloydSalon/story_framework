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
- Breaking changes to the serialized format must bump
  `StoryDocumentCodec.currentSchemaVersion` and ship a migration. New element
  types and interaction kinds are additive (older readers preserve them as
  `UnknownElement`) and keep the version.
- Update `CHANGELOG.md` under the next unreleased version.

## Releasing

Releases are automated. To release a new version:

1. Bump `version` in `pubspec.yaml` and add a matching `## <version>`
   section at the top of `CHANGELOG.md`.
2. Merge to `main`.

The **Release** workflow sees the untagged version, runs the checks, and
pushes the `v<version>` tag. The tag starts the **Publish** workflow, which
checks that the tag matches `pubspec.yaml`, runs the checks again, and
publishes to pub.dev. A version already on pub.dev is skipped, and merges
that don't change the version do nothing.

One-time setup:

- **Deploy key:** generate a key pair without a passphrase
  (`ssh-keygen -t ed25519 -f release_key`, then press Enter at both
  passphrase prompts), add `release_key.pub`
  under **Settings → Deploy keys** with write access, and add the private
  `release_key` as the `RELEASE_DEPLOY_KEY` repository secret. Tags pushed
  with the default `GITHUB_TOKEN` don't start other workflows, so the
  Release workflow pushes tags with this key.
- **pub.dev:** on the package's **Admin** tab, enable publishing from
  GitHub Actions for this repository with the tag pattern `v{{version}}`,
  and require the GitHub Actions environment `pub.dev`. pub.dev only
  automates packages that already exist, so the first version is published
  by hand with `flutter pub publish`.
- **Tag protection (recommended):** add a ruleset for `v*` tags so only
  the deploy key can create them; otherwise anyone with push access can
  publish by pushing a tag.
