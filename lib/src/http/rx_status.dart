/// Reactive Status for state management.
///
/// Represents the current status of an async operation.
/// Used with [MagicStateMixin] to handle loading/success/error states.
///
/// ## Usage
///
/// ```dart
/// class UserController extends MagicController with MagicStateMixin<User> {
///   Future<void> fetchUser() async {
///     change(null, status: RxStatus.loading());
///     try {
///       final user = await api.getUser();
///       change(user, status: RxStatus.success());
///     } catch (e) {
///       change(null, status: RxStatus.error(e.toString()));
///     }
///   }
/// }
/// ```
enum RxStatusType {
  /// Initial state, no data loaded yet.
  empty,

  /// Data is being loaded.
  loading,

  /// Data loaded successfully.
  success,

  /// An error occurred.
  error,
}

/// Immutable status class for reactive state management.
class RxStatus {
  /// The type of status.
  final RxStatusType type;

  /// Optional error message when status is [RxStatusType.error].
  final String? message;

  const RxStatus._(this.type, [this.message]);

  /// Create a loading status.
  ///
  /// ```dart
  /// change(null, status: RxStatus.loading());
  /// ```
  const RxStatus.loading() : this._(RxStatusType.loading);

  /// Create a success status.
  ///
  /// ```dart
  /// change(user, status: RxStatus.success());
  /// ```
  const RxStatus.success() : this._(RxStatusType.success);

  /// Create an error status with a message.
  ///
  /// ```dart
  /// change(null, status: RxStatus.error('Failed to load user'));
  /// ```
  const RxStatus.error(String message) : this._(RxStatusType.error, message);

  /// Create an empty status (initial state).
  ///
  /// ```dart
  /// change(null, status: RxStatus.empty());
  /// ```
  const RxStatus.empty() : this._(RxStatusType.empty);

  /// Check if status is loading.
  bool get isLoading => type == RxStatusType.loading;

  /// Check if status is success.
  bool get isSuccess => type == RxStatusType.success;

  /// Check if status is error.
  bool get isError => type == RxStatusType.error;

  /// Check if status is empty.
  bool get isEmpty => type == RxStatusType.empty;

  @override
  String toString() => 'RxStatus($type${message != null ? ', $message' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RxStatus && type == other.type && message == other.message;

  @override
  int get hashCode => type.hashCode ^ (message?.hashCode ?? 0);
}
