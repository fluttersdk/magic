/// The image cache on the web, where there is nothing to keep: the browser's
/// HTTP cache holds images. It exists so code shared with the native build,
/// a sign-out that clears the cache, compiles on both.
final class MagicImageCache {
  MagicImageCache._();

  /// The cache `MagicImage` draws through.
  static final MagicImageCache instance = MagicImageCache._();

  /// Removes every stored image: there are none.
  Future<void> clear() async {}

  /// Trims the disk to its cap: there is no disk, so nothing is freed.
  Future<int> sweep() async => 0;
}
