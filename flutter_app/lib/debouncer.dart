import 'dart:async';

/// Debounces calls to [afterDelay()].
class Debouncer {
  final Duration delay;

  Timer? _delayTimer;
  void Function()? _savedCallback;

  Debouncer({
    required this.delay,
  });

  /// Executes [callback] after [delay], cancels the previous request if any.
  void afterDelay(void Function() callback) {
    _savedCallback = callback;
    _delayTimer?.cancel();
    _delayTimer = Timer(
      delay,
      () {
        callback();
        _savedCallback = null;
      },
    );
  }

  void flush() {
    _savedCallback?.call();
    cancel();
  }

  /// Stops the pending callback being fired, if any.
  void cancel() {
    print('Cancel');
    _delayTimer?.cancel();
    _savedCallback = null;
  }
}
