class EventFormBrowserGuard {
  EventFormBrowserGuard({
    required bool Function() isDirty,
    required void Function() flush,
  });
  void dispose() {}
}
