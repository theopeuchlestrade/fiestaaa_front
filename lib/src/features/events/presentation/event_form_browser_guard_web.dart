import 'dart:js_interop';
import 'package:web/web.dart' as web;

class EventFormBrowserGuard {
  EventFormBrowserGuard({
    required bool Function() isDirty,
    required void Function() flush,
  }) {
    _beforeUnload = ((web.Event event) {
      if (!isDirty()) return;
      flush();
      event.preventDefault();
      (event as web.BeforeUnloadEvent).returnValue = '';
    }).toJS;
    _visibility = ((web.Event event) {
      if (web.document.visibilityState == 'hidden') flush();
    }).toJS;
    web.window.addEventListener('beforeunload', _beforeUnload);
    web.document.addEventListener('visibilitychange', _visibility);
  }
  late final JSFunction _beforeUnload, _visibility;
  void dispose() {
    web.window.removeEventListener('beforeunload', _beforeUnload);
    web.document.removeEventListener('visibilitychange', _visibility);
  }
}
