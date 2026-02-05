import 'package:magic/magic.dart';

/// Todo Model.
///
/// Represents a todo item in the database.
class Todo extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'todos';

  @override
  String get resource => 'todos';

  @override
  bool get useLocal => true;

  @override
  bool get useRemote => false;

  @override
  List<String> get fillable => [
    'title',
    'description',
    'is_completed',
    'priority',
  ];

  // Typed accessors
  String? get title => getAttribute('title') as String?;
  set title(String? value) => setAttribute('title', value);

  String? get description => getAttribute('description') as String?;
  set description(String? value) => setAttribute('description', value);

  bool get isCompleted => (getAttribute('is_completed') ?? 0) == 1;
  set isCompleted(bool value) => setAttribute('is_completed', value ? 1 : 0);

  int get priority => (getAttribute('priority') ?? 0) as int;
  set priority(int value) => setAttribute('priority', value);

  // Static helpers
  static Future<Todo?> find(dynamic id) =>
      InteractsWithPersistence.findById<Todo>(id, Todo.new);

  static Future<List<Todo>> all() =>
      InteractsWithPersistence.allModels<Todo>(Todo.new);
}
