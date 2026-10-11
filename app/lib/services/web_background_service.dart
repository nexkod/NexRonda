import 'web_background_stub.dart'
    if (dart.library.js_interop) 'web_background_web.dart'
    if (dart.library.io) 'web_background_io.dart';

class WebBackgroundService {
  static void enable(String roomName) {
    WebBackgroundServiceImpl.enable(roomName);
  }

  static void disable() {
    WebBackgroundServiceImpl.disable();
  }
}
