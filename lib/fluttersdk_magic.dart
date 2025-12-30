library;

// Export plugins
export 'package:fluttersdk_wind/fluttersdk_wind.dart';
export 'package:dio/dio.dart';
export 'package:go_router/go_router.dart';
export 'package:intl/intl.dart';
export 'package:jiffy/jiffy.dart';
export 'package:image_picker/image_picker.dart';
export 'package:flutter_secure_storage/flutter_secure_storage.dart';
export 'package:shared_preferences/shared_preferences.dart';
export 'package:share_plus/share_plus.dart';
export 'package:timezone/timezone.dart';
export 'package:logger/logger.dart';
export 'package:file_picker/file_picker.dart';

// Foundation
export 'src/foundation/application.dart';
export 'src/foundation/config_repository.dart';
export 'src/foundation/env.dart';
export 'src/foundation/magic.dart';
export 'src/foundation/magic_app_widget.dart';

// Config
export 'config/app.dart';
export 'config/auth.dart';
export 'config/cache.dart';
export 'config/database.dart';
export 'config/logging.dart';
export 'config/localization.dart';
export 'config/network.dart';
export 'config/view.dart';

// Support
export 'src/support/service_provider.dart';
export 'src/support/carbon.dart';
export 'src/support/carbon_extension.dart';
export 'src/support/date_manager.dart';
export 'src/helpers/date_helpers.dart';

// Routing
export 'src/routing/magic_router.dart';
export 'src/routing/magic_router_outlet.dart';
export 'src/routing/route_definition.dart';

// Facades
export 'src/facades/config.dart';
export 'src/facades/route.dart';

// HTTP & MVC
export 'src/http/request.dart';
export 'src/http/rx_status.dart';
export 'src/http/magic_controller.dart';
export 'src/http/kernel.dart';
export 'src/http/middleware/magic_middleware.dart';
export 'src/http/middleware/authorize_middleware.dart';

// Cache
export 'src/cache/cache_manager.dart';
export 'src/cache/cache_service_provider.dart';
export 'src/facades/crypt.dart';
export 'src/facades/cache.dart';

// Security
export 'src/security/magic_vault_service.dart';
export 'src/security/vault_service_provider.dart';
export 'src/facades/vault.dart';

// UI
export 'src/ui/magic_feedback.dart';
export 'src/ui/magic_view_registry.dart';
export 'src/ui/magic_view.dart';
export 'src/ui/magic_form.dart';
export 'src/ui/magic_form_data.dart';
export 'src/ui/magic_responsive_view.dart';

// Network
export 'src/network/magic_response.dart';
export 'src/network/contracts/magic_network_interceptor.dart';
export 'src/network/contracts/network_driver.dart';
export 'src/network/drivers/dio_network_driver.dart';
export 'src/network/network_service_provider.dart';
export 'src/facades/http.dart';

// Logging
export 'src/logging/contracts/logger_driver.dart';
export 'src/logging/drivers/console_logger_driver.dart';
export 'src/logging/drivers/stack_logger_driver.dart';
export 'src/logging/log_manager.dart';

export 'src/facades/log.dart';

// Database
export 'src/database/database_manager.dart';
export 'src/database/database_service_provider.dart';
export 'src/database/schema/blueprint.dart';
export 'src/database/query/query_builder.dart';
export 'src/database/migrations/migration.dart';
export 'src/database/migrations/migrator.dart';
export 'src/facades/db.dart';
export 'src/facades/schema.dart';

// Seeding & Factories
export 'src/database/seeding/factory.dart';
export 'src/database/seeding/seeder.dart';

// Eloquent ORM
export 'src/database/eloquent/model.dart';
export 'src/database/eloquent/concerns/has_timestamps.dart';
export 'src/database/eloquent/concerns/interacts_with_persistence.dart';

// Authentication
export 'src/auth/authenticatable.dart';
export 'src/auth/auth_result.dart';
export 'src/auth/contracts/guard.dart';
export 'src/auth/auth_manager.dart';
export 'src/auth/guards/base_guard.dart';
export 'src/auth/guards/bearer_token_guard.dart';
export 'src/auth/guards/basic_auth_guard.dart';
export 'src/auth/guards/api_key_guard.dart';
export 'src/auth/auth_interceptor.dart';
export 'src/facades/auth.dart';
export 'src/auth/auth_service_provider.dart';

// Localization
export 'src/localization/translator.dart';
export 'src/localization/lang_delegate.dart';
export 'src/localization/contracts/translation_loader.dart';
export 'src/localization/loaders/json_asset_loader.dart';
export 'src/facades/lang.dart';
export 'src/localization/localization_service_provider.dart';

// Validation
export 'src/validation/contracts/rule.dart';
export 'src/validation/rules/required.dart';
export 'src/validation/rules/email.dart';
export 'src/validation/rules/min.dart';
export 'src/validation/rules/max.dart';
export 'src/validation/rules/confirmed.dart';
export 'src/validation/rules/same.dart';
export 'src/validation/rules/accepted.dart';
export 'src/validation/exceptions/validation_exception.dart';
export 'src/validation/validator.dart';
export 'src/validation/form_validator.dart';
export 'src/concerns/validates_requests.dart';

// Events
export 'src/events/magic_event.dart';
export 'src/events/magic_listener.dart';
export 'src/events/event_dispatcher.dart';
export 'src/events/event_service_provider.dart';
export 'src/facades/event.dart';

// Framework Events
export 'src/auth/events/auth_events.dart';
export 'src/auth/events/gate_events.dart';
export 'src/database/events/db_events.dart';
export 'src/database/events/model_events.dart';
export 'src/foundation/events/app_events.dart';

// Storage
export 'config/filesystems.dart';
export 'src/storage/contracts/storage_disk.dart';
export 'src/storage/drivers/local_disk.dart';
export 'src/storage/storage_manager.dart';
export 'src/storage/magic_file.dart';
export 'src/storage/magic_file_extensions.dart';
export 'src/facades/storage.dart';
export 'src/facades/pick.dart';

// Authorization (Gate)
export 'src/auth/gate_manager.dart';
export 'src/facades/gate.dart';
export 'src/policies/policy.dart';
export 'src/providers/gate_service_provider.dart';
export 'src/ui/magic_can.dart';
