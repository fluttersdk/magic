import 'package:magic/magic.dart';
import '../app/providers/route_service_provider.dart';
import '../app/providers/app_service_provider.dart';

/// Application Configuration
Map<String, dynamic> get appConfig => {
  'app': {
    'name': env('APP_NAME', 'Magic App'),
    'env': env('APP_ENV', 'production'),
    'debug': env<bool>('APP_DEBUG', false),
    'url': env('APP_URL', 'http://localhost'),
    'key': env('APP_KEY'),
    'providers': [
      (app) => RouteServiceProvider(app),
      (app) => AppServiceProvider(app),

      (app) => LocalizationServiceProvider(app),
      (app) => DatabaseServiceProvider(app),
      (app) => NetworkServiceProvider(app),
      (app) => VaultServiceProvider(app),
      (app) => AuthServiceProvider(app),
    ],
  },
};
