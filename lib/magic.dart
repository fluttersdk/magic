library;

// Export plugins
export 'package:wind_kit/wind_kit.dart';
export 'package:dio/dio.dart';
export 'package:go_router/go_router.dart';
export 'package:intl/intl.dart';
export 'package:jiffy/jiffy.dart';
export 'package:flutter_secure_storage/flutter_secure_storage.dart';
export 'package:timezone/timezone.dart';
export 'package:logger/logger.dart';

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
export 'config/logging.dart';
export 'config/localization.dart';
export 'config/network.dart';
export 'config/routing.dart';
export 'config/view.dart';

// Support
export 'src/support/service_provider.dart';
export 'src/support/carbon.dart';
export 'src/support/carbon_extension.dart';
export 'src/support/date_manager.dart';
export 'src/helpers/date_helpers.dart';
export 'src/support/number.dart';
export 'src/support/str.dart';
export 'src/support/cast.dart';
export 'src/support/arr.dart';
export 'src/support/app_lifecycle.dart';
export 'src/support/latest_read.dart';
export 'src/support/poll.dart';
export 'src/support/countdown.dart';
export 'src/support/debouncer.dart';
export 'src/support/url_generator.dart';

// Actions
export 'src/actions/action_outcome.dart';
export 'src/actions/action_request_failed.dart';
export 'src/actions/magic_action.dart';
export 'src/actions/runs_actions.dart';

// Perf
export 'src/perf/magic_perf_hooks.dart';

// Forms
export 'src/forms/magic_form_object.dart';

// Routing
export 'src/routing/magic_overlay_page.dart' show MagicOverlayPresentation;
export 'src/routing/magic_platform_page.dart';
export 'src/routing/magic_router.dart';
export 'src/routing/magic_router_outlet.dart';
export 'src/routing/resource_controller.dart';
export 'src/routing/route_definition.dart';
export 'src/routing/title_manager.dart';

// Facades
export 'src/facades/config.dart';
export 'src/facades/route.dart';

// HTTP & MVC
export 'src/http/request.dart';
export 'src/http/rx_status.dart';
export 'src/http/magic_controller.dart';
export 'src/http/magic_paginator.dart';
export 'src/http/owns_timers.dart';
export 'src/http/kernel.dart';
export 'src/http/middleware/magic_middleware.dart';
export 'src/http/middleware/authorize_middleware.dart';

// Cache
export 'src/cache/cache_store.dart';
export 'src/cache/cache_manager.dart';
export 'src/cache/cache_service_provider.dart';
export 'src/cache/drivers/file_store.dart';
export 'src/cache/events/cache_events.dart';
export 'src/facades/cache.dart';

// Security
export 'src/security/magic_vault_service.dart';
export 'src/security/vault_service_provider.dart';
export 'src/facades/vault.dart';

// UI
export 'src/ui/magic_builder.dart';
export 'src/ui/magic_selector.dart';
export 'src/ui/magic_feedback.dart';
export 'src/ui/magic_view_registry.dart';
export 'src/ui/magic_view.dart';
export 'src/ui/refetches_on_mount.dart';
export 'src/ui/submits_once.dart';
export 'src/ui/magic_paginated_list_view.dart';
export 'src/ui/magic_form.dart';
export 'src/ui/magic_form_data.dart';
export 'src/ui/magic_responsive_view.dart';
export 'src/ui/magic_title.dart';

// Network
export 'src/network/magic_response.dart';
export 'src/network/contracts/magic_network_interceptor.dart';
export 'src/network/contracts/network_driver.dart';
export 'src/network/drivers/dio_network_driver.dart';
export 'src/network/drivers/fake_network_driver.dart';
export 'src/network/network_service_provider.dart';
export 'src/facades/http.dart';

// Logging
export 'src/logging/contracts/logger_driver.dart';
export 'src/logging/drivers/console_logger_driver.dart';
export 'src/logging/drivers/stack_logger_driver.dart';
export 'src/logging/log_manager.dart';

export 'src/facades/log.dart';

// Testing
export 'src/testing/fake_auth_manager.dart';
export 'src/testing/fake_cache_manager.dart';
export 'src/testing/fake_vault_service.dart';
export 'src/testing/fake_log_manager.dart';

// Database
export 'src/database/contracts/local_model_store.dart';

// Eloquent ORM
export 'src/database/eloquent/model.dart';
export 'src/database/eloquent/concerns/has_timestamps.dart';
export 'src/database/eloquent/concerns/interacts_with_persistence.dart';
export 'src/database/eloquent/casts/casts_attributes.dart';
export 'src/database/eloquent/casts/enum_cast.dart';
export 'src/database/eloquent/casts/list_cast.dart';
export 'src/database/eloquent/exceptions/mass_assignment_exception.dart';

// Data (id-keyed remote resource caches, over the Eloquent model shape)
export 'src/data/repository.dart';
export 'src/data/repository_query.dart';

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
export 'src/localization/message_selector.dart';
export 'src/facades/lang.dart';
export 'src/localization/localization_service_provider.dart';
export 'src/localization/localization_interceptor.dart';

// Validation
export 'src/validation/contracts/rule.dart';
export 'src/validation/contracts/async_rule.dart';
export 'src/validation/contracts/size_rule.dart';
export 'src/validation/rules/required.dart';
export 'src/validation/rules/email.dart';
export 'src/validation/rules/url.dart';
export 'src/validation/rules/min.dart';
export 'src/validation/rules/max.dart';
export 'src/validation/rules/confirmed.dart';
export 'src/validation/rules/same.dart';
export 'src/validation/rules/accepted.dart';
export 'src/validation/rules/unique.dart';
export 'src/validation/rules/in.dart';
export 'src/validation/rules/in_list.dart';
export 'src/validation/exceptions/validation_exception.dart';
export 'src/validation/exceptions/authorization_exception.dart';
export 'src/validation/validator.dart';
export 'src/validation/form_validator.dart';
export 'src/validation/form_request.dart';
export 'src/concerns/validates_requests.dart';
export 'src/validation/rules/uuid.dart';
export 'src/validation/rules/boolean.dart';
export 'src/validation/rules/numeric.dart';
export 'src/validation/rules/integer.dart';
export 'src/validation/rules/comparison.dart';
export 'src/validation/rules/between.dart';
export 'src/validation/rules/regex.dart';
export 'src/validation/rules/date.dart';
export 'src/validation/rules/nullable.dart';
export 'src/validation/rules/required_if.dart';
export 'src/validation/rules/array_rule.dart';

// Events
export 'src/events/magic_event.dart';
export 'src/events/magic_listener.dart';
export 'src/events/event_dispatcher.dart';
export 'src/events/base_event_service_provider.dart';
export 'src/events/reports_breadcrumb.dart';
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
export 'src/storage/drivers/local/local_adapter_contract.dart';
export 'src/storage/drivers/local_disk.dart';
export 'src/storage/storage_manager.dart';
export 'src/storage/magic_file.dart';
export 'src/storage/magic_file_extensions.dart';
export 'src/storage/images/images.dart';
export 'src/facades/storage.dart';

// Session
export 'src/session/session_store.dart';
export 'src/session/session_scoped.dart';
export 'src/session/session_scope.dart';
export 'src/facades/session.dart';

// Authorization (Gate)
export 'src/auth/gate_manager.dart';
export 'src/auth/gate_result.dart';
export 'src/facades/gate.dart';
export 'src/policies/policy.dart';
export 'src/providers/gate_service_provider.dart';
export 'src/ui/magic_can.dart';

// Launch
export 'package:url_launcher/url_launcher.dart' show LaunchMode;

export 'src/launch/launch_adapter.dart';
export 'src/launch/launch_service.dart';
export 'src/launch/launch_service_provider.dart';
export 'src/facades/launch.dart';

// CLI integrations (dowel dev-tooling ecosystem). Magic-aware dowel
// provider + tinker REPL only. The dusk/telescope adapters live in the sibling
// `magic_devtools` package; add it as a dev_dependency and import
// `package:magic_devtools/dusk.dart` / `package:magic_devtools/telescope.dart`.
// Magic core no longer depends on the dusk or telescope packages directly.
export 'src/cli/magic_dowel_provider.dart';
export 'src/cli/tinker_integration.dart';
