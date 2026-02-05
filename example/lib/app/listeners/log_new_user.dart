import 'package:magic/magic.dart';
import '../../models/user.dart';

class LogNewUser extends MagicListener<ModelCreated> {
  @override
  Future<void> handle(ModelCreated event) async {
    if (event.model is User) {
      final user = event.model as User;
      Log.info('🎉 New user joined: ${user.name}');
    }
  }
}
