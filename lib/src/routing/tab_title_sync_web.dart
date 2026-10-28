import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The browser's Navigation API object, or `null` where the browser has none.
@JS('navigation')
external _Navigation? get _navigation;

/// The slice of `window.navigation` this file listens through.
extension type _Navigation._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);

  external void removeEventListener(String type, JSFunction listener);
}

/// Calls [onEntryChanged] after every change of the browser's current history
/// entry, which includes the `replaceState` the router makes when a page
/// redirects, and once now for a change made before this was attached.
///
/// Deferred to its own task: the event fires inside the history call, before
/// the engine has finished its own bookkeeping around it.
///
/// Returns the function that stops listening. A callback already queued when it
/// is called still runs once, and only touches the global `document`.
void Function() watchHistoryEntries(void Function() onEntryChanged) {
  final _Navigation? navigation = _navigation;
  if (navigation == null) return () {};

  final JSFunction listener = (JSAny _) {
    Timer.run(onEntryChanged);
  }.toJS;
  navigation.addEventListener('currententrychange', listener);
  Timer.run(onEntryChanged);

  return () => navigation.removeEventListener('currententrychange', listener);
}

/// The document's current title.
String readDocumentTitle() => web.document.title;

/// Sets the document's title.
void writeDocumentTitle(String title) => web.document.title = title;
