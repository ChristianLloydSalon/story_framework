# Interactive Content

Polls, quizzes, questions, sliders, countdowns, links, and product tags are
`InteractiveElement`s. They are part of the document (authored, serialized,
validated) and are rendered by the built-in `StoryInteractiveRenderer`.

```dart
InteractiveElement(
  id: 'poll',
  transform: const StoryTransform(
    position: StoryPoint(540, 900),
    size: StorySize(860, 560),
  ),
  accentColor: const StoryColor(0xFFFF5722),
  interaction: StoryPoll(
    question: 'Tea or coffee?',
    choices: const [
      StoryChoice(id: 'tea', label: 'Tea'),
      StoryChoice(id: 'coffee', label: 'Coffee'),
    ],
  ),
)
```

## Interactions

| Interaction | Viewer action | Event |
|---|---|---|
| `StoryPoll` | Vote for a choice; results show when known | `StoryChoiceSelectedEvent` |
| `StoryQuiz` | Answer; the correct choice is revealed | `StoryChoiceSelectedEvent` with `isCorrect` |
| `StoryQuestion` | Type and send a reply | `StoryQuestionRepliedEvent` |
| `StorySlider` | Drag the emoji handle to rate 0–1 | `StorySliderSubmittedEvent` |
| `StoryCountdown` | Watch it tick; set a reminder | `StoryCountdownReminderEvent` |
| `StoryLink` | Tap the link | `StoryLinkTappedEvent` |
| `StoryProductTag` | Tap the product | `StoryProductTappedEvent` |
| `StoryCustomInteraction` | App-defined | `StoryCustomInteractionEvent` |

The framework never opens URLs, sends replies, or stores votes itself. Every
interaction goes to your app:

```dart
StoryViewer(
  document: document,
  onInteraction: (event) => switch (event) {
    StoryChoiceSelectedEvent() => api.vote(event.element.id, event.choiceId),
    StoryLinkTappedEvent(:final url) => launchUrl(url),
    _ => null,
  },
)
```

## State

Runtime state (who voted for what, results, ratings, reminders) lives in a
`StoryInteractionController`, not in the document. The viewer creates one,
or you pass your own to seed and refresh state:

```dart
final interactions = StoryInteractionController(
  onInteraction: send,
  allowChangingAnswers: false, // votes and ratings are final
  initialStates: {
    'poll': StoryChoiceState(
      selectedChoiceId: previousVote,        // the viewer's earlier vote
      counts: {'tea': 120, 'coffee': 87},    // aggregated results
    ),
  },
);
// Later, when fresh results arrive:
interactions.setState('poll', StoryChoiceState(selectedChoiceId: 'tea', counts: latest));

StoryViewer(document: document, interactionController: interactions);
```

| State | Used by |
|---|---|
| `StoryChoiceState(selectedChoiceId, counts)` | Polls and quizzes. Empty `counts` shows only the viewer's own choice |
| `StorySliderState(value, average)` | Sliders. `average` is shown after rating |
| `StoryQuestionState(replies)` | Questions (reply texts are not kept) |
| `StoryCountdownState(reminderSet)` | Countdowns |

## Navigation and playback

- In the viewer, interactive elements are drawn in a layer **above the
  gesture layer**, aligned with the rest of the item. Touching a sticker
  never navigates; touching anywhere else still does. As a result,
  interactive elements always paint above an item's static elements in the
  viewer.
- Typing a reply and dragging a slider hold playback with
  `StoryPauseReason.interaction`, using counted holds
  (`StoryController.acquirePause`), so several widgets can hold at once
  without releasing each other's hold.

## Accessibility

- Choices, send, reminder, link, and product buttons are screen-reader
  buttons with descriptive labels, such as "Vote Coffee". After voting,
  labels include the share and whether the choice is yours or correct.
- Buttons are keyboard-focusable and activate with Enter or Space.
- Sliders are semantic sliders (increase/decrease actions in 10% steps).
  Keyboard users move the handle with the arrow keys and submit with Enter.
- Countdowns announce "Ends in …" or "… has ended". Sent replies are
  announced through a live region.

## Previews

Without a `StoryInteractionScope` (for example in `StoryItemView` used
directly, an editor, or an export), or with `enabled: false`, interactive
elements render as inert previews: same look, no input, no live text field.

## Custom interactions

```dart
registry.replace(StoryInteractiveRenderer(customBuilders: {
  'emoji-rain': (context, element, interaction, renderContext) =>
      EmojiRain(emoji: interaction.data['emoji'] as String),
}));
```

Custom widgets can read `StoryInteractionScope.maybeOf(context)` and report
actions with `controller.reportCustom(element, itemId, 'action', data: ...)`.

The building blocks `StoryInteractionCard`, `StoryInteractionButton`,
`StoryInteractionPill`, and `StoryFitWidth` are public, so custom
interactions can match the built-in look. Sizes are in canvas units, and
content scales down if the element box is too small.
