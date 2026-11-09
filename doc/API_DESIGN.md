# API Design Conventions

## Naming

- Public types are prefixed `Story` when the name would otherwise be generic
  (`StoryPoint`, `StoryColor`, `StoryDocument`). Specific types keep natural
  names (`ImageElement`, `EmojiSticker`, `FixedItemDuration`).
- Serialization identifiers are lower-case strings exposed as `typeId`
  constants (`ImageElement.typeId == 'image'`).
- Booleans read as statements: `visible`, `locked`, `isTimeBased`, `isValid`.
- Durations use `Duration`; angles are radians; geometry is canvas units.

## Models

- Immutable, `@immutable`, with `==`/`hashCode` based on value.
- Collections are copied into unmodifiable lists/maps on construction.
- `copyWith` returns a new instance. Nullable fields cannot be cleared through
  `copyWith`; construct a new value instead.
- Sealed hierarchies for closed sets of variants; extension happens through
  `Custom*` variants keyed by string identifiers, never by subclassing core
  models.
- Models never hold live resources.

## Behavior and services

- Collaborators are injected through constructors with sensible defaults; no
  global singletons or service locators.
- Extension points are `abstract interface class`es with small surfaces.
- Controllers expose immutable state snapshots and must be disposed by their
  owner. Use after disposal throws `ControllerDisposedException`.
- Methods document whether they are synchronous or asynchronous, what they
  throw, and who owns returned resources.

## Errors

- Every framework error extends `StoryException`; use the most specific
  subtype.
- Never swallow failures silently. Recoverable problems are reported (for
  example validation warnings or error states), not ignored.
- Error messages and `toString()` must not include secrets such as signed URL
  query strings.

## Compatibility

- Semantic versioning. During `0.x`, minor versions may break APIs; breaking
  changes are listed in `CHANGELOG.md`.
- The serialized document format is versioned separately
  (`StoryDocumentCodec.currentSchemaVersion`) and always migratable.
