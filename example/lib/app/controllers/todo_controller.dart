import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../../resources/views/todos/index_view.dart';
import '../models/todo.dart';

/// Todo Controller - Demonstrates Magic Eloquent ORM operations.
///
/// ## Features
/// - Full CRUD operations using Todo model
/// - Real-time UI updates with MagicStateMixin
/// - Eloquent-style queries
///
/// ## Routes
/// ```dart
/// MagicRoute.page('/todos', () => TodoController.instance.index());
/// ```
class TodoController extends MagicController with MagicStateMixin<List<Todo>> {
  /// Singleton accessor with lazy registration.
  static TodoController get instance => Magic.findOrPut(TodoController.new);

  // ---------------------------------------------------------------------------
  // Actions (return Widget from resources/views)
  // ---------------------------------------------------------------------------

  /// GET /todos - List all todos.
  Widget index() {
    if (isEmpty) {
      loadTodos();
    }
    return const TodosIndexView();
  }

  // ---------------------------------------------------------------------------
  // Business Logic (CRUD Operations with Eloquent)
  // ---------------------------------------------------------------------------

  /// Load all todos from database.
  Future<void> loadTodos() async {
    setLoading();

    try {
      final todos = await Todo.all();
      // Sort: incomplete first, then by priority desc, then by created_at desc
      todos.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.priority != b.priority) {
          return b.priority.compareTo(a.priority);
        }
        return 0;
      });

      setSuccess(todos);
    } catch (e) {
      setError('Failed to load todos: $e');
    }
  }

  /// Create a new todo.
  Future<void> createTodo({
    required String title,
    String? description,
    int priority = 0,
  }) async {
    try {
      final todo = Todo()
        ..title = title
        ..description = description
        ..isCompleted = false
        ..priority = priority;

      await todo.save();

      Magic.success('Success', 'Todo created!');
      await loadTodos();
    } catch (e) {
      Magic.error('Error', 'Failed to create todo: $e');
    }
  }

  /// Toggle todo completion status.
  Future<void> toggleTodo(Todo todo) async {
    try {
      todo.isCompleted = !todo.isCompleted;
      await todo.save();
      await loadTodos();
    } catch (e) {
      Magic.error('Error', 'Failed to update todo: $e');
    }
  }

  /// Update a todo.
  Future<void> updateTodo(
    Todo todo, {
    String? title,
    String? description,
    int? priority,
  }) async {
    try {
      if (title != null) todo.title = title;
      if (description != null) todo.description = description;
      if (priority != null) todo.priority = priority;

      await todo.save();

      Magic.success('Success', 'Todo updated!');
      await loadTodos();
    } catch (e) {
      Magic.error('Error', 'Failed to update todo: $e');
    }
  }

  /// Delete a todo.
  Future<void> deleteTodo(Todo todo) async {
    try {
      await todo.delete();

      Magic.success('Success', 'Todo deleted!');
      await loadTodos();
    } catch (e) {
      Magic.error('Error', 'Failed to delete todo: $e');
    }
  }

  /// Delete all completed todos.
  Future<void> clearCompleted() async {
    try {
      final completedTodos =
          rxState?.where((t) => t.isCompleted).toList() ?? [];
      for (final todo in completedTodos) {
        await todo.delete();
      }

      Magic.success(
        'Success',
        '${completedTodos.length} completed todos cleared!',
      );
      await loadTodos();
    } catch (e) {
      Magic.error('Error', 'Failed to clear completed: $e');
    }
  }

  /// Get counts for stats.
  int get totalCount => rxState?.length ?? 0;
  int get completedCount => rxState?.where((t) => t.isCompleted).length ?? 0;
  int get pendingCount => totalCount - completedCount;
}
