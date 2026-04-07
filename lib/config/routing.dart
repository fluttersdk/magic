/// Routing Default Configuration.
///
/// These defaults are merged into Config during initialization.
/// Users can override any value via their own config files.
Map<String, dynamic> get defaultRoutingConfig => {
  'routing': {'url_strategy': null},
};
