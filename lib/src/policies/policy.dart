/// Base class for organizing authorization policies.
///
/// Policies group related authorization logic together, making it easier
/// to manage permissions for specific models or features.
///
/// ## Creating a Policy
///
/// ```dart
/// class PostPolicy extends Policy {
///   @override
///   void register() {
///     Gate.define('view-post', view);
///     Gate.define('update-post', update);
///     Gate.define('delete-post', delete);
///   }
///
///   bool view(Model user, Post post) {
///     return post.isPublished || user.id == post.userId;
///   }
///
///   bool update(Model user, Post post) {
///     return user.id == post.userId;
///   }
///
///   bool delete(Model user, Post post) {
///     return user.isAdmin || user.id == post.userId;
///   }
/// }
/// ```
///
/// ## Registering Policies
///
/// In your `GateServiceProvider.boot()`:
///
/// ```dart
/// PostPolicy().register();
/// CommentPolicy().register();
/// ```
abstract class Policy {
  /// Register the policy's abilities with the Gate.
  ///
  /// Override this method to define your abilities.
  void register();
}
