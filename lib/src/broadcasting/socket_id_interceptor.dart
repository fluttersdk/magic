import '../facades/echo.dart';
import '../network/contracts/magic_network_interceptor.dart';
import '../network/magic_response.dart';

/// The Socket ID Interceptor.
///
/// Attaches the broadcast connection's socket id as `X-Socket-ID` to every
/// outgoing HTTP request, the header Laravel Echo adds to axios. Laravel reads
/// it for `broadcast(...)->toOthers()` and excludes that socket from the
/// broadcast, so the device that made the request does not receive its own
/// event back.
///
/// The value is read from [Echo.socketId] at request time. While the socket is
/// down (or the `null` driver is in use) the id is `null` and the request is
/// left untouched: the header is never sent empty.
///
/// ## Registration
///
/// Registered by [BroadcastServiceProvider] when the default connection is not
/// `'null'` and a network driver is bound. You do not need to add it manually.
class SocketIdInterceptor extends MagicNetworkInterceptor {
  @override
  dynamic onRequest(MagicRequest request) {
    final socketId = Echo.socketId;

    if (socketId != null) {
      request.headers['X-Socket-ID'] = socketId;
    }

    return request;
  }
}
