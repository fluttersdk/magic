import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../models/user.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  void register() {
    //
  }

  @override
  Future<void> boot() async {
    // Register User model for Auth
    Auth.manager.setUserFactory((data) => User.fromMap(data));
  }
}
