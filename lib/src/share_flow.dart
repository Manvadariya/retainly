import 'package:flutter/foundation.dart';

class ShareFlow {
  // Indicates whether a share-driven modal flow is active.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  // Indicates the app is checking for an initial share (cold start).
  // Splash should wait while this is true to avoid flashing to landing.
  static final ValueNotifier<bool> pendingInitial = ValueNotifier<bool>(false);
}
