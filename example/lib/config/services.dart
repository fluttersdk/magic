import 'package:magic/magic.dart';

/// Third-party Services Configuration
Map<String, dynamic> get servicesConfig => {
  'services': {
    'mail': {
      'driver': env('MAIL_DRIVER', 'smtp'),
      'host': env('MAIL_HOST', 'smtp.mailtrap.io'),
      'port': env<int>('MAIL_PORT', 587),
      'username': env('MAIL_USERNAME', ''),
      'password': env('MAIL_PASSWORD', ''),
    },
    'stripe': {
      'key': env('STRIPE_KEY', ''),
      'secret': env('STRIPE_SECRET', ''),
    },
  },
};
