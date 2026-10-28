/// Without a browser there is no tab to keep in step: nothing is watched.
void Function() watchHistoryEntries(void Function() onEntryChanged) => () {};

/// Never read: [watchHistoryEntries] never calls back off the web.
String readDocumentTitle() => '';

/// Never written: [watchHistoryEntries] never calls back off the web.
void writeDocumentTitle(String title) {}
