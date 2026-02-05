import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../app/controllers/welcome_controller.dart';

class WelcomeView extends MagicView<WelcomeController> {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.appName), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Welcome to ${controller.appName}!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                trans('welcome', {'name': 'Anilcan'}),
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📦 Config Values',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _configRow('app.name', controller.appName),
                    _configRow('app.env', controller.appEnv),
                    _configRow('database.host', controller.dbHost),
                    _configRow('database.port', controller.dbPort.toString()),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: () => MagicRoute.to('/todos'),
                icon: const Icon(Icons.list),
                label: const Text('Todo List (Database Demo)'),
              ),
              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: () => MagicRoute.to('/user'),
                icon: const Icon(Icons.person),
                label: const Text('User Profile (MVC Demo)'),
              ),
              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: () => MagicRoute.to('/dashboard'),
                icon: const Icon(Icons.dashboard),
                label: const Text('Dashboard (Responsive Demo)'),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () {
                  Magic.snackbar('Config', 'App Name: ${controller.appName}');
                },
                icon: const Icon(Icons.settings),
                label: const Text('Show Config Snackbar'),
              ),
              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: () => MagicRoute.push('/about'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Go to About'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _configRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$key: ',
            style: const TextStyle(fontFamily: 'monospace', color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }
}
