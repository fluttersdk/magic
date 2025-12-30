/// Framework Default Configuration.
///
/// These defaults are merged into Config during initialization.
/// Users can override any value via their own config files.
Map<String, dynamic> get defaultAppConfig => {
      'app': {
        'name': 'Magic App',
        'env': 'production',
        'key': null,
        'debug': false,
        'url': 'http://localhost',
        'providers': [],
      },
    };
