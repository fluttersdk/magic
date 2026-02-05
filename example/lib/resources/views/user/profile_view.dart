import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/controllers/user_controller.dart';
import '../../../app/models/user.dart';

/// User Profile View.
///
/// Displays user profile with refresh and error simulation.
class UserProfileView extends StatelessWidget {
  final UserController controller;

  const UserProfileView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: controller.renderState(
        (user) => _buildUserCard(user),
        onError: (msg) => _buildError(msg),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final userName = user.name ?? 'Unknown';
    final userEmail = user.email ?? '';

    return Center(
      child: WDiv(
        className: 'p-6 max-w-sm',
        child: WDiv(
          className: 'bg-white rounded-xl shadow-lg p-6',
          children: [
            WDiv(
              className: 'flex flex-col items-center gap-4',
              children: [
                WDiv(
                  className:
                      'w-20 h-20 bg-blue-500 rounded-full flex items-center justify-center',
                  child: WText(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    className: 'text-white text-2xl font-bold',
                  ),
                ),
                WText(userName, className: 'text-xl font-bold text-gray-900'),
                WText(userEmail, className: 'text-gray-500'),
                WDiv(
                  className: 'flex flex-row gap-2 mt-4',
                  children: [
                    WAnchor(
                      onTap: () => controller.refresh(),
                      child: WDiv(
                        className: 'px-4 py-2 bg-blue-500 rounded-lg',
                        child: WText('Refresh', className: 'text-white'),
                      ),
                    ),
                    WAnchor(
                      onTap: () => controller.simulateError(),
                      child: WDiv(
                        className: 'px-4 py-2 bg-red-500 rounded-lg',
                        child: WText('Simulate Error', className: 'text-white'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: WDiv(
        className: 'p-6 flex flex-col items-center gap-4',
        children: [
          WIcon(Icons.error_outline, className: 'text-red-500 text-6xl'),
          WText(message, className: 'text-red-500 text-center'),
          WAnchor(
            onTap: () => controller.refresh(),
            child: WDiv(
              className: 'px-6 py-3 bg-blue-500 rounded-lg mt-4',
              child: WText('Try Again', className: 'text-white'),
            ),
          ),
        ],
      ),
    );
  }
}
