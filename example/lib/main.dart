import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';
import 'config/auth.dart';
import 'config/cache.dart';
import 'config/database.dart';
import 'config/logging.dart';
import 'config/network.dart';
import 'config/routing.dart';
import 'config/view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => authConfig,
      () => cacheConfig,
      () => databaseConfig,
      () => loggingConfig,
      () => networkConfig,
      () => routingConfig,
      () => viewConfig,
    ],
  );

  runApp(MagicApplication(title: 'Example'));
}
