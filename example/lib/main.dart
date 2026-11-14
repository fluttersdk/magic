import 'package:material_ui/material_ui.dart';
import 'package:magic/magic.dart';

import 'config/app.dart';
import 'config/routing.dart';
import 'config/view.dart';
import 'config/auth.dart';
import 'config/network.dart';
import 'config/cache.dart';
import 'config/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => routingConfig,
      () => viewConfig,
      () => authConfig,
      () => networkConfig,
      () => cacheConfig,
      () => loggingConfig,
    ],
  );

  runApp(MagicApplication(title: 'Example'));
}
