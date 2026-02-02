import '../../providers/keybindings_provider.dart';

/// Identifies the physical input source that triggered an action.
enum InputSource {
  keyboard,
  pointer,
  sideButton,
}

/// Prevents duplicate handling of the same action from different sources.
class InputActionGate {
  InputActionGate._();

  static final InputActionGate instance = InputActionGate._();

  DateTime? _lastHandledAt;
  BindableAction? _lastAction;
  InputSource? _lastSource;

  /// Returns whether [action] should be handled for [source] within [window].
  bool shouldHandle(
    BindableAction action,
    InputSource source, {
    Duration window = const Duration(milliseconds: 30),
  }) {
    final now = DateTime.now();
    if (_lastHandledAt != null &&
        _lastAction == action &&
        _lastSource != source &&
        now.difference(_lastHandledAt!) <= window) {
      return false;
    }
    _lastHandledAt = now;
    _lastAction = action;
    _lastSource = source;
    return true;
  }

  /// Clears the last handled action and time window.
  void reset() {
    _lastHandledAt = null;
    _lastAction = null;
    _lastSource = null;
  }
}
