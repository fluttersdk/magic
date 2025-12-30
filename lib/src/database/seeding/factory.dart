import 'package:faker/faker.dart';

import '../eloquent/model.dart';

/// The base Factory class for generating fake model data.
///
/// Factories provide a fluent API for creating models with fake data,
/// similar to Laravel factories. Perfect for database seeding and testing.
///
/// ## Creating a Factory
///
/// ```dart
/// class UserFactory extends Factory<User> {
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
/// final admins = await UserFactory()
///     .state({'role': 'admin'})
///     .count(5)
///     .create();
///
/// // Create without saving (in-memory only)
/// final mockUsers = UserFactory().count(10).make();
/// ```
abstract class Factory<T extends Model> {
  /// The count of models to create.
  int? _count;

  /// State overrides to merge with definition.
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

  /// Set the number of models to create.
  ///
  /// ```dart
  /// await UserFactory().count(50).create();
  /// ```
  Factory<T> count(int count) {
    _count = count;
    return this;
  }

  /// Apply a state override to the factory.
  ///
  /// States are merged with the definition, allowing selective overrides.
  ///
  /// ```dart
  /// await UserFactory()
  ///     .state({'role': 'admin', 'is_verified': true})
  ///     .create();
  /// ```
  Factory<T> state(Map<String, dynamic> state) {
    _states = {..._states, ...state};
    return this;
  }

  /// Create and persist models to the database.
  ///
  /// This calls `model.save()` for each created model.
  /// Note: Your model must use `InteractsWithPersistence` mixin.
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
    final iterations = _count ?? 1;

    for (var i = 0; i < iterations; i++) {
      final attributes = {...definition(), ..._states};
      final model = newInstance()..fill(attributes);
      // Use dynamic call since save() comes from InteractsWithPersistence mixin
      await (model as dynamic).save();
      models.add(model);
    }

    return models;
  }

  /// Create models without persisting to the database.
  ///
  /// Useful for testing or creating temporary model instances.
  ///
  /// ```dart
  /// final mockUsers = UserFactory().count(10).make();
  /// // Models are in memory only, not saved to DB
  /// ```
  List<T> make() {
    final models = <T>[];
    final iterations = _count ?? 1;

    for (var i = 0; i < iterations; i++) {
      final attributes = {...definition(), ..._states};
      final model = newInstance()..fill(attributes);
      models.add(model);
    }

    return models;
  }
}
