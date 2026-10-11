import 'dart:js_interop';

@JS('window.enableBackgroundIntercom')
external void _enableBackgroundIntercom(JSString? roomName);

@JS('window.disableBackgroundIntercom')
external void _disableBackgroundIntercom();

class WebBackgroundServiceImpl {
  static void enable(String roomName) {
    try {
      _enableBackgroundIntercom(roomName.toJS);
    } catch (_) {}
  }

  static void disable() {
    try {
      _disableBackgroundIntercom();
    } catch (_) {}
  }
}
