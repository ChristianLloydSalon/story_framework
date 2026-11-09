# Serialization and Validation

## Format

`StoryDocumentCodec` writes plain JSON:

```json
{
  "schemaVersion": 1,
  "id": "trip",
  "revision": 0,
  "canvas": { "width": 1080, "height": 1920, "background": { "kind": "color", "color": "#FF000000" }, "scaling": "contain" },
  "assets": [ { "id": "hero", "type": "image", "source": { "kind": "network", "url": "https://..." } } ],
  "groups": [
    {
      "id": "alice",
      "items": [
        {
          "id": "beach",
          "duration": { "kind": "fixed", "ms": 5000 },
          "elements": [
            {
              "type": "image", "id": "photo",
              "transform": { "x": 540, "y": 960, "width": 1080, "height": 1920, "rotation": 0, "scale": 1 },
              "opacity": 1, "zIndex": 0, "visible": true, "locked": false,
              "source": { "kind": "reference", "assetId": "hero" }, "fit": "cover"
            }
          ]
        }
      ]
    }
  ]
}
```

Conventions:

- Durations are integer milliseconds (`ms`, `trimStartMs`, ...).
- Colors are `#AARRGGBB` strings.
- Timestamps are ISO-8601 UTC strings.
- Enums are stored by name.
- Drawing points are a flat `[x0, y0, x1, y1, ...]` list.
- Null fields and empty maps are omitted; readers apply defaults.
- Encoding is deterministic: the same document always produces the same JSON.

Never serialized: live controllers, widgets, decoders, and
`StreamStorySource`s (encoding one throws a `SerializationException`).
`WidgetElement` stores only its `widgetType` and JSON `data`.

## Errors

Decoding failures throw `SerializationException` with a `path` such as
`groups[0].items[2].elements[1].transform.x`.

## Versioning and migration

- `StoryDocumentCodec.currentSchemaVersion` is the version written.
- Documents with a **newer** version are rejected, so old apps never silently
  drop data they do not understand.
- Documents with an **older** version are upgraded by the
  `StoryDocumentMigration`s passed to the codec, one version at a time, on raw
  JSON. A missing step is an error.
- Any change to the serialized shape bumps the schema version and ships a
  migration.

## Unknown elements

`UnknownElementPolicy` controls element types the codec does not recognize:

| Policy | Result |
|---|---|
| `preserve` (default) | Decoded as `UnknownElement`; re-encoded with its original JSON plus any edits to common fields |
| `skip` | Dropped |
| `error` | `SerializationException` |

## Validation

`StoryDocumentValidator` returns a `StoryValidationResult` of
`StoryValidationIssue`s, each with a severity, stable `code`, message, and
path. `isValid` means no errors; warnings (empty groups, blank text,
unserializable stream sources) are allowed.

Built-in checks: non-empty and unique ids, canvas dimensions, safe area,
opacity/volume ranges, transform finiteness and positivity, trim ranges, font
size and weight, gradient colors and stops, group expiry order, asset
references, media-duration targets, and network URL schemes.

Add application rules by implementing `StoryValidationRule`:

```dart
final validator = StoryDocumentValidator(rules: [MyBrandRule()]);
validator.validateOrThrow(document); // throws InvalidCompositionException
```
