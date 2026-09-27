/// A contract for a [MagicEvent] that wants to show up in a crash reporter's
/// breadcrumb trail (Sentry, Crashlytics, ...) before an error happens.
///
/// The reporter's own integration (`magic_sentry`'s `Event.listenAny`
/// listener, for example) checks `event is ReportsBreadcrumb` on every
/// dispatch and translates a match into a breadcrumb record, so an event
/// author opts in by implementing this and nothing else has to know the
/// reporter exists.
///
/// [breadcrumbData] is a WHITELIST, not a dump of the event. It never carries
/// a URL with a query string, an auth token, or a raw payload value: a
/// breadcrumb trail is uploaded to a third party, and a field that looks
/// harmless in the event (a webhook URL, a bearer token) is exactly what a
/// breadcrumb must not repeat.
abstract interface class ReportsBreadcrumb {
  /// The breadcrumb category (Sentry's grouping key, e.g. `'auth'`,
  /// `'navigation'`).
  String get breadcrumbCategory;

  /// The human-readable message shown for this breadcrumb.
  String get breadcrumbMessage;

  /// The whitelisted extra data attached to the breadcrumb.
  Map<String, Object?> get breadcrumbData;
}
