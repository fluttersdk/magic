/// Drops a stale answer that lands after a newer read for the same key
/// already started, in place of a hand-rolled read counter.
///
/// Generalises the per-field counters `MonitorController` used to hand-roll
/// one at a time (`_checksRead`/`_seriesRead`/`_uptimeRead`) and depools'
/// `_requestId` guard: [begin] bumps [key]'s counter and hands back the new
/// value as a token, and [isCurrent] answers whether that token is still the
/// newest one issued for [key]. An async read calls [begin] before it starts
/// and [isCurrent] before it paints its result, so an answer that lands after
/// a newer read for the same key is dropped instead of overwriting it.
class LatestRead {
  /// The key a caller tracking a single read at a time never has to name.
  static const Object _defaultKey = Object();

  /// The newest token issued per key.
  final Map<Object, int> _tokens = {};

  /// Starts a new read for [key] (default: a single untracked read),
  /// returning the token this read owns.
  int begin([Object key = _defaultKey]) {
    final int next = (_tokens[key] ?? 0) + 1;
    _tokens[key] = next;

    return next;
  }

  /// Whether [token] is still [key]'s newest issued token, i.e. whether the
  /// read holding it is still the one allowed to act on what it found.
  bool isCurrent(int token, [Object key = _defaultKey]) =>
      _tokens[key] == token;

  /// Bumps [key]'s counter without starting a new read, so whatever read is
  /// currently in flight for [key] is dropped when it lands.
  void invalidate([Object key = _defaultKey]) {
    _tokens[key] = (_tokens[key] ?? 0) + 1;
  }
}
