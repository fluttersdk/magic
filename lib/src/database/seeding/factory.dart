import 'package:faker/faker.dart';

import '../eloquent/model.dart';

/// The base Factory class for generating fake model data.
///
/// Factories provide a fluent API for creating models with fake data,
/// similar to Laravel factories. Perfect for database seeding and testing.
///
/// Like Laravel, a factory fills its models unguarded: `id`, timestamps and
/// any other key missing from [Model.fillable] land on the model, so a
/// factory can build a model exactly as the API would return it.
///
/// ## Creating a Factory
///
/// ```dart
/// class UserFactory extends Factory<User> {
///   @override
///   Factory<User> newFactory() => UserFactory();
///
///   @override
///   User newInstance() => User();
///
///   @override
///   Map<String, dynamic> definition() {
///     return {
///       'name': faker.person.name(),
///       'email': faker.internet.email(),
///       'is_active': true,
///     };
///   }
/// }
///
/// extension UserFactoryStates on Factory<User> {
///   Factory<User> admin() => state({'role': 'admin'});
/// }
/// ```
///
/// ## Using a Factory
///
/// ```dart
/// // Create a single user
/// final user = await UserFactory().create();
///
/// // Create 50 users
/// final users = await UserFactory().count(50).create();
///
/// // Create with custom state
/// final admins = await UserFactory().admin().count(5).create();
///
/// // Create without saving (in-memory only)
/// final mockUsers = UserFactory().count(10).make();
/// ```
abstract class Factory<T extends Model> {
  /// The count of models to create.
  int? _count;

  /// State overrides to merge with definition.
  ///
  /// Never mutated in place: [state] builds a new map, so copies may share it.
  Map<String, dynamic> _states = {};

  /// Access the Faker instance for generating fake data.
  ///
  /// ```dart
  /// faker.person.name()      // John Doe
  /// faker.internet.email()   // john@example.com
  /// faker.lorem.sentence()   // Lorem ipsum...
  /// faker.date.dateTime()    // Random datetime
  /// faker.randomGenerator.integer(100) // 0-100
  /// ```
  Faker get faker => Faker();

  /// Define the model's default state.
  ///
  /// Override this to return a map of attribute values using Faker.
  ///
  /// ```dart
  /// @override
  /// Map<String, dynamic> definition() {
  ///   return {
  ///     'name': faker.person.name(),
  ///     'email': faker.internet.email(),
  ///     'created_at': DateTime.now().toIso8601String(),
  ///   };
  /// }
  /// ```
  Map<String, dynamic> definition();

  /// Create a new instance of the model.
  ///
  /// Override this to return an empty model instance.
  ///
  /// ```dart
  /// @override
  /// User newInstance() => User();
  /// ```
  T newInstance();

  /// Create a fresh, unconfigured factory of the same type.
  ///
  /// [state] and [count] return a copy instead of changing this factory, and
  /// Dart cannot construct "the same subclass" on its own, so every factory
  /// answers with its own constructor.
  ///
  /// ```dart
  /// @override
  /// Factory<User> newFactory() => UserFactory();
  /// ```
  Factory<T> newFactory();

  /// Return a copy of this factory that builds [count] models.
  ///
  /// This factory is left unchanged.
  ///
  /// ```dart
  /// await UserFactory().count(50).create();
  /// ```
  Factory<T> count(int count) => _copy(count: count);

  /// Return a copy of this factory with [state] merged over its states.
  ///
  /// States are merged with the definition, allowing selective overrides.
  /// This factory is left unchanged, so a shared base can branch safely.
  ///
  /// ```dart
  /// await UserFactory()
  ///     .state({'role': 'admin', 'is_verified': true})
  ///     .create();
  /// ```
  Factory<T> state(Map<String, dynamic> state) {
    return _copy(states: {..._states, ...state});
  }

  /// Build the attribute maps without creating any model.
  ///
  /// Always returns a list, one map per model: a single map when no [count]
  /// was set, matching [make] and [create].
  ///
  /// ```dart
  /// final payload = UserFactory().raw().single;
  /// ```
  List<Map<String, dynamic>> raw() {
    return [for (var i = 0; i < (_count ?? 1); i++) _attributes()];
  }

  /// Create and persist models to the database.
  ///
  /// This calls `model.save()` for each created model. The model is filled
  /// unguarded, so every definition key (including `id` and timestamps) is
  /// forwarded to the persistence layer, but `save()` itself runs with the
  /// guard back on.
  /// Note: Your model must use `InteractsWithPersistence` mixin.
  ///
  /// Throws [StateError] when `save()` refuses a model (any result other than
  /// `true`), naming the model type and, when the model exposes
  /// `validationErrors`, the field errors from the refused save.
  ///
  /// ```dart
  /// // Create one
  /// final user = (await UserFactory().create()).first;
  ///
  /// // Create many
  /// final users = await UserFactory().count(50).create();
  /// ```
  Future<List<T>> create() async {
    final models = <T>[];

    for (final attributes in raw()) {
      final model = _build(attributes);
      // Use dynamic call since save() comes from InteractsWithPersistence mixin
      final dynamic saved = await (model as dynamic).save();

      if (saved != true) {
        throw StateError(
          'Factory<$T>.create() refused to save a ${model.runtimeType}: '
          '${_describeRefusal(model)}',
        );
      }

      models.add(model);
    }

    return models;
  }

  /// Describe why `save()` refused [model], for [create]'s [StateError].
  ///
  /// Reads `validationErrors` dynamically since only models mixing in
  /// `InteractsWithPersistence` expose it; a model without that mixin (or one
  /// whose most recent save carried no field errors) falls back to a generic
  /// message.
  String _describeRefusal(T model) {
    try {
      final dynamic errors = (model as dynamic).validationErrors;
      if (errors is Map<String, List<String>> && errors.isNotEmpty) {
        return 'validation errors: $errors';
      }
    } catch (_) {
      // The model does not expose validationErrors; fall through.
    }

    return 'save() did not return true';
  }

  /// Create models without persisting to the database.
  ///
  /// The models are left with `exists` false and every attribute dirty, as
  /// Laravel's `make()` leaves them.
  ///
  /// ```dart
  /// final mockUsers = UserFactory().count(10).make();
  /// // Models are in memory only, not saved to DB
  /// ```
  List<T> make() => raw().map(_build).toList();

  /// Merge this factory's states over a fresh definition.
  Map<String, dynamic> _attributes() {
    return {...definition(), ..._states};
  }

  /// Fill a new model with [attributes], bypassing mass-assignment protection.
  T _build(Map<String, dynamic> attributes) {
    return Model.unguarded(() => newInstance()..fill(attributes));
  }

  /// Copy this factory's configuration into [newFactory], overriding
  /// whichever of [count] and [states] is given.
  Factory<T> _copy({int? count, Map<String, dynamic>? states}) {
    return newFactory()
      .._count = count ?? _count
      .._states = states ?? _states;
  }
}
