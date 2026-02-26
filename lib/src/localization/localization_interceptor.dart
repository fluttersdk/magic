import '../network/magic_response.dart';
import '../network/contracts/magic_network_interceptor.dart';
import '../support/date_manager.dart';
import 'translator.dart';

/// The Localization Interceptor.
///
/// Attaches `Accept-Language` and `X-Timezone` headers to every outgoing
/// HTTP request. Values are sourced from the [Translator] and [DateManager]
/// singletons at request-time, so they always reflect the current state.
///
/// ## Headers
///
/// - `Accept-Language` — The current locale language code (e.g. `en`, `tr`).
/// - `X-Timezone` — The current IANA timezone identifier (e.g. `Europe/Istanbul`).
///
/// ## Registration
///
/// This interceptor is automatically registered by [LocalizationServiceProvider]
/// when the localization system is enabled. You do not need to add it manually.
class LocalizationInterceptor extends MagicNetworkInterceptor {
  @override
  dynamic onRequest(MagicRequest request) {
    request.headers['Accept-Language'] =
        Translator.instance.locale.languageCode;
    request.headers['X-Timezone'] = DateManager.instance.timezoneName;

    return request;
  }

  @override
  dynamic onResponse(MagicResponse response) => response;

  @override
  dynamic onError(MagicError error) => error;
}
