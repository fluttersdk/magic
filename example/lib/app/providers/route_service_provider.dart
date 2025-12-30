import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../../routes/app.dart';
import '../../routes/auth.dart';
import '../kernel.dart';

class RouteServiceProvider extends ServiceProvider {
  RouteServiceProvider(super.app);

  @override
  void register() {
    // Register middleware kernel (logic moved from onInit)
    registerKernel();
  }

  @override
  Future<void> boot() async {
    // Register routes
    registerAppRoutes();
    registerAuthRoutes();
  }
}
