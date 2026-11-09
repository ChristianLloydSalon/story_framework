import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_framework/engine.dart';

import '../../helpers/engine_fakes.dart';

void main() {
  testWidgets('backgrounding holds playback and resuming releases it',
      (tester) async {
    final harness = EngineHarness();
    final controller = StoryController(
      document: StoryDocument(id: 'd', groups: [
        StoryGroup(id: 'g', items: [StoryItem(id: 'i')]),
      ]),
      clock: harness.clock,
      tickerFactory: harness.createTicker,
    );
    final binding = StoryAppLifecycleBinding(controller);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(
        controller.state.value.pauseReasons, {StoryPauseReason.appBackground});

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(controller.state.value.pauseReasons, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.dispose();
    expect(controller.state.value.pauseReasons, isEmpty,
        reason: 'disposing the binding clears its reason');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await controller.dispose();
  });
}
