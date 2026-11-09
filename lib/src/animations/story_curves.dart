import 'package:flutter/animation.dart';

/// Curves that can be named in `StoryTransitionConfiguration.curve`.
const Map<String, Curve> storyCurves = {
  'linear': Curves.linear,
  'ease': Curves.ease,
  'easeIn': Curves.easeIn,
  'easeOut': Curves.easeOut,
  'easeInOut': Curves.easeInOut,
  'easeInCubic': Curves.easeInCubic,
  'easeOutCubic': Curves.easeOutCubic,
  'easeInOutCubic': Curves.easeInOutCubic,
  'fastOutSlowIn': Curves.fastOutSlowIn,
  'decelerate': Curves.decelerate,
  'bounceOut': Curves.bounceOut,
  'elasticOut': Curves.elasticOut,
};

/// The curve named [name], or [Curves.easeInOut] for unknown names.
Curve storyCurveNamed(String name) => storyCurves[name] ?? Curves.easeInOut;
