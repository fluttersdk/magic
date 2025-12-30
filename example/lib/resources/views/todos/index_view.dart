import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../../../app/controllers/todo_controller.dart';
import '../../../app/models/todo.dart';

/// Todo List Index View - Rebuilt with Wind UI.
class TodosIndexView extends MagicView<TodoController> {
  const TodosIndexView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: WText('📝 Todo List', className: 'text-xl font-bold text-white'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            onPressed: controller.loadTodos,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      // Use WDiv for the main body
      body: WDiv(
        className: 'w-full h-full bg-white',
        child: controller.renderState(
          (todos) => _buildTodoList(context, todos),
          onLoading: _buildLoading(),
          onError: (error) => _buildError(error),
          onEmpty: _buildEmptyState(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTodoDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Todo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
      ),
    );
  }

  Widget _buildLoading() {
    return WDiv(
      className: 'flex flex-col justify-center items-center h-full gap-4',
      children: [
        const CircularProgressIndicator(),
        WText('Loading todos...', className: 'text-gray-500'),
      ],
    );
  }

  Widget _buildError(String error) {
    return WDiv(
      className: 'flex flex-col justify-center items-center h-full gap-6 p-8',
      children: [
        WIcon(Icons.error_outline, className: 'text-red-500 text-6xl'),
        WText(error, className: 'text-red-500 text-center text-lg'),
        WButton(
          onTap: controller.loadTodos,
          className: 'bg-indigo-600 px-6 py-2 rounded-lg',
          child: WText('Retry', className: 'text-white font-medium'),
        ),
      ],
    );
  }

  Widget _buildTodoList(BuildContext context, List<Todo> todos) {
    return WDiv(
      className: 'flex flex-col h-full',
      children: [
        // Stats bar
        _buildStatsBar(todos),

        // Todo list (Expanded replacement using flex-1)
        WDiv(
          className: 'flex-1 overflow-y-auto pb-20',
          children: todos.map((todo) => _buildTodoItem(context, todo)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsBar(List<Todo> todos) {
    final total = todos.length;
    final completed = todos.where((t) => t.isCompleted).length;
    final pending = total - completed;

    return WDiv(
      className:
          'flex flex-row justify-around p-4 bg-indigo-50 border-b border-indigo-100',
      children: [
        _statItem('Total', total, 'indigo'),
        _statItem('Pending', pending, 'orange'),
        _statItem('Done', completed, 'green'),
      ],
    );
  }

  Widget _statItem(String label, int count, String colorName) {
    return WDiv(
      className: 'flex flex-col items-center',
      children: [
        WText('$count', className: 'text-2xl font-bold text-$colorName-600'),
        WText(label, className: 'text-gray-600 text-sm'),
      ],
    );
  }

  Widget _buildTodoItem(BuildContext context, Todo todo) {
    final isCompleted = todo.isCompleted;
    final priority = todo.priority;

    // We keep Dismissible as it's a functional widget
    return Dismissible(
      key: Key('todo_${todo.id}'),
      direction: DismissDirection.endToStart,
      background: WDiv(
        className: 'flex flex-row justify-end items-center bg-red-500 pr-5',
        child: WIcon(Icons.delete, className: 'text-white text-2xl'),
      ),
      onDismissed: (_) => controller.deleteTodo(todo),
      child: WAnchor(
        onTap: () => _showEditTodoDialog(context, todo),
        child: WDiv(
          className:
              'flex flex-row items-center p-4 border-b border-gray-100 bg-white hover:bg-gray-50 transition-colors',
          children: [
            // Checkbox
            WCheckbox(
              value: isCompleted,
              onChanged: (_) => controller.toggleTodo(todo),
              className: 'text-green-500 rounded focus:ring-green-500',
            ),

            WDiv(className: 'w-4'), // Spacer
            // Title & Description
            WDiv(
              className: 'flex flex-col flex-1',
              children: [
                WText(
                  todo.title ?? '',
                  className:
                      'text-base font-medium ${isCompleted ? "line-through text-gray-400" : "text-gray-800"}',
                ),
                if (todo.description != null && todo.description!.isNotEmpty)
                  WText(
                    todo.description!,
                    className: 'text-sm text-gray-500 truncate mt-1',
                  ),
              ],
            ),

            WDiv(className: 'w-2'), // Spacer
            // Priority Badge
            _priorityBadge(priority),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(int priority) {
    final colors = ['gray', 'orange', 'red'];
    final labels = ['Low', 'Med', 'High'];
    final color = colors[priority];

    return WDiv(
      className:
          'px-2 py-1 rounded-full bg-$color-100 border border-$color-200',
      child: WText(
        labels[priority],
        className: 'text-xs font-medium text-$color-700',
      ),
    );
  }

  Widget _buildEmptyState() {
    return WDiv(
      className: 'flex flex-col items-center justify-center p-8 gap-4',
      children: [
        WIcon(Icons.check_circle_outline, className: 'text-8xl text-gray-300'),
        WText('No todos yet!', className: 'text-xl text-gray-600 font-medium'),
        WText('Tap + to add your first todo', className: 'text-gray-400'),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs (Refactored to use WInput)
  // ---------------------------------------------------------------------------

  void _showAddTodoDialog(BuildContext context) {
    String title = '';
    String description = '';
    int priority = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: WText('Add Todo', className: 'text-lg font-bold'),
          content: WDiv(
            className: 'flex flex-col gap-4 w-full min-w-[300px]',
            children: [
              WDiv(
                className: 'flex flex-col gap-2',
                children: [
                  WText(
                    'Title',
                    className: 'text-sm font-medium text-gray-700',
                  ),
                  WInput(
                    value: title,
                    onChanged: (v) => setState(() => title = v),
                    placeholder: 'What needs to be done?',
                    className:
                        'w-full p-2 border border-gray-300 rounded focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none transition-all',
                  ),
                ],
              ),
              WDiv(
                className: 'flex flex-col gap-2',
                children: [
                  WText(
                    'Description',
                    className: 'text-sm font-medium text-gray-700',
                  ),
                  WInput(
                    value: description,
                    onChanged: (v) => setState(() => description = v),
                    placeholder: 'Optional details...',
                    className:
                        'w-full p-2 border border-gray-300 rounded focus:border-indigo-500 outline-none',
                  ),
                ],
              ),
              WDiv(
                className: 'flex flex-col gap-2',
                children: [
                  WText(
                    'Priority',
                    className: 'text-sm font-medium text-gray-700',
                  ),
                  WDiv(
                    className: 'flex flex-row gap-2',
                    children: [
                      _priorityOption(
                        0,
                        priority,
                        (p) => setState(() => priority = p),
                      ),
                      _priorityOption(
                        1,
                        priority,
                        (p) => setState(() => priority = p),
                      ),
                      _priorityOption(
                        2,
                        priority,
                        (p) => setState(() => priority = p),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.trim().isEmpty) {
                  Magic.error('Error', 'Title is required');
                  return;
                }
                controller.createTodo(
                  title: title.trim(),
                  description: description.trim().isEmpty
                      ? null
                      : description.trim(),
                  priority: priority,
                );
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTodoDialog(BuildContext context, Todo todo) {
    String title = todo.title ?? '';
    String description = todo.description ?? '';
    int priority = todo.priority;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: WText('Edit Todo', className: 'text-lg font-bold'),
          content: WDiv(
            className: 'flex flex-col gap-4 w-full min-w-[300px]',
            children: [
              WDiv(
                className: 'flex flex-col gap-2',
                children: [
                  WText(
                    'Title',
                    className: 'text-sm font-medium text-gray-700',
                  ),
                  WInput(
                    value: title,
                    onChanged: (v) => setState(() => title = v),
                    className:
                        'w-full p-2 border border-gray-300 rounded focus:border-indigo-500 outline-none',
                  ),
                ],
              ),
              WDiv(
                className: 'flex flex-col gap-2',
                children: [
                  WText(
                    'Description',
                    className: 'text-sm font-medium text-gray-700',
                  ),
                  WInput(
                    value: description,
                    onChanged: (v) => setState(() => description = v),
                    className:
                        'w-full p-2 border border-gray-300 rounded focus:border-indigo-500 outline-none',
                  ),
                ],
              ),
              WDiv(
                className: 'flex flex-col gap-2',
                children: [
                  WText(
                    'Priority',
                    className: 'text-sm font-medium text-gray-700',
                  ),
                  WDiv(
                    className: 'flex flex-row gap-2',
                    children: [
                      _priorityOption(
                        0,
                        priority,
                        (p) => setState(() => priority = p),
                      ),
                      _priorityOption(
                        1,
                        priority,
                        (p) => setState(() => priority = p),
                      ),
                      _priorityOption(
                        2,
                        priority,
                        (p) => setState(() => priority = p),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.deleteTodo(todo);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.trim().isEmpty) {
                  Magic.error('Error', 'Title is required');
                  return;
                }
                controller.updateTodo(
                  todo,
                  title: title.trim(),
                  description: description.trim().isEmpty
                      ? null
                      : description.trim(),
                  priority: priority,
                );
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityOption(int value, int groupValue, Function(int) onTap) {
    final labels = ['Low', 'Med', 'High'];
    final colors = ['gray', 'orange', 'red'];
    final isSelected = value == groupValue;
    final color = colors[value];

    return Expanded(
      child: WButton(
        onTap: () => onTap(value),
        className: isSelected
            ? 'bg-$color-100 border-2 border-$color-500 py-2 rounded text-center'
            : 'bg-white border border-gray-200 py-2 rounded text-center hover:bg-gray-50',
        child: WText(
          labels[value],
          className: isSelected
              ? 'text-$color-700 font-bold text-sm'
              : 'text-gray-600 text-sm',
        ),
      ),
    );
  }
}
