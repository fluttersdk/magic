import 'package:web/web.dart' as web;

/// Steps the browser one history entry back, as its Back button does.
///
/// The browser answers asynchronously with a `popstate` for the entry before,
/// which the engine hands the router as platform route information.
const void Function() browserHistoryBack = _back;

void _back() => web.window.history.back();
