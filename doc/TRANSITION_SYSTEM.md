# Transition System

`package:story_framework/animations.dart` animates between story items.

## Which transition runs

| Navigation | Transition |
|---|---|
| First item shown | none |
| Within a group | the incoming item's `StoryItem.transition`, else `StoryViewerConfig.itemTransition` (default: cut) |
| Across groups | `StoryViewerConfig.groupTransition` (default: `cube`, 400 ms) |
| Reduced motion | `StoryViewerConfig.reducedMotionTransition` (default: `fade`, 150 ms) replaces any of the above |

`StoryTransitionConfiguration` names the transition (`type`), its
`duration`, its `curve` (by name, see `storyCurves`), and optional JSON
`parameters`. Items store it in the document, so it is serialized with them.
The transition duration is independent of the item's display duration.

## Presets

| Id | Effect |
|---|---|
| `none` | Cut |
| `fade` | Cross-fade |
| `slide` | Push the outgoing item off one edge |
| `scale` | Grow and fade the incoming item in |
| `zoom` | Zoom the outgoing item toward the viewer while it fades |
| `cube` | Rotate both items like faces of a cube |
| `horizontalReveal` | Wipe in from the entering edge |
| `verticalReveal` | Wipe in from the top |

Directional presets use `StoryTransitionFrame.sign`: forward in left-to-right
layouts enters from the right, and backward navigation or right-to-left
layouts mirror it.

A shared-element transition (morphing a tray avatar into the viewer) belongs
to the host app's route transition and is not a preset.

## Custom transitions

```dart
final class FlipTransition extends StoryTransition {
  const FlipTransition();

  @override
  String get id => 'flip';

  @override
  Widget build(BuildContext context, StoryTransitionFrame frame) =>
      MyFlip(animation: frame.animation, front: frame.outgoing, back: frame.incoming);
}

final transitions = StoryTransitionRegistry.withDefaults([const FlipTransition()]);
StoryViewer(document: document, transitionRegistry: transitions);
```

`StoryTransitionFrame` provides the curved `animation` (0 shows only the
outgoing item, 1 only the incoming one), both items, the navigation
`direction`, the `textDirection`, and `parameters`. A transition must show
only the incoming item when the animation reaches 1.

An unknown type cuts instead and is reported once through
`FlutterError.reportError`, so a typo in a document never breaks playback.

## Switcher

`StoryTransitionSwitcher` runs the animation whenever its `childKey`
changes. Both items are reparented with global keys, so their state (decoded
images, players) survives the transition instead of reloading when it ends.
A new change mid-animation starts a fresh transition from the current item.

## Reduced motion

`StoryViewerConfig.motion` is `system` by default (it follows the platform's
reduce-motion setting through `MediaQuery.disableAnimations`), or forced to
`reduced` or `full`. Reduced motion also makes overlay show and hide
immediate.
