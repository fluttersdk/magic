import 'tab_title_sync_stub.dart'
    if (dart.library.js_interop) 'tab_title_sync_web.dart'
    as platform;

/// The character appended for one write: not ASCII whitespace, so
/// `document.title` keeps it, and zero width, so a tab never shows it.
const String _detour = '\u{200B}';

/// Re-sends the page title so the browser attaches it to the history entry it
/// has just swapped in.
///
/// Chrome keeps a title per history entry. When the router moves, the Flutter
/// engine calls `history.pushState` or `replaceState` after the page has built,
/// which creates a new entry, and the title written BEFORE that call does not
/// follow it: the tab falls back to the previous entry's title, or to the bare
/// host when there is none. Blink only reports a title to the browser when it
/// changes, so writing the same text again does nothing. Writing a different
/// one first and the real one straight after reports both, and the last report
/// wins.
///
/// [read] returns the title the page currently holds and [write] sets it. An
/// empty title is left alone.
void resendTitle({
  required String Function() read,
  required void Function(String title) write,
}) {
  final String title = read();
  if (title.isEmpty) return;

  write('$title$_detour');
  write(title);
}

/// Keeps the browser tab title in step with the page title across navigation.
///
/// On the web, calls [resendTitle] after every change of the browser's current
/// history entry, through the Navigation API, and once on attach. Where the
/// browser has no Navigation API, and on every other platform, it does nothing.
///
/// Returns the function that detaches it; calling it twice is harmless.
void Function() attachTabTitleSync() {
  return platform.watchHistoryEntries(
    () => resendTitle(
      read: platform.readDocumentTitle,
      write: platform.writeDocumentTitle,
    ),
  );
}
