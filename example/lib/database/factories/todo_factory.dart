import 'package:magic/magic.dart';

import '../../app/models/todo.dart';

/// TodoFactory
///
/// Generates fake Todo instances for seeding and testing.
class TodoFactory extends Factory<Todo> {
  @override
  Todo newInstance() => Todo();

  @override
  Map<String, dynamic> definition() {
    return {
      'title': faker.lorem.sentence(),
      'description': faker.lorem.sentences(3).join(' '),
      'is_completed': faker.randomGenerator.boolean() ? 1 : 0,
      'priority': faker.randomGenerator.integer(3), // 0-2
    };
  }

  /// Create a high priority todo.
  TodoFactory highPriority() {
    return state({'priority': 2}) as TodoFactory;
  }

  /// Create a completed todo.
  TodoFactory completed() {
    return state({'is_completed': 1}) as TodoFactory;
  }

  /// Create an incomplete todo.
  TodoFactory incomplete() {
    return state({'is_completed': 0}) as TodoFactory;
  }
}
