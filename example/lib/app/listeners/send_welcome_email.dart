import 'package:magic/magic.dart';
import '../events/user_registered.dart';

class SendWelcomeEmail extends MagicListener<UserRegistered> {
  @override
  Future<void> handle(UserRegistered event) async {
    // In a real app, you would use Mail facade here
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
