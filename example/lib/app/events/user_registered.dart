import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../../models/user.dart';

class UserRegistered extends MagicEvent {
  final User user;
  UserRegistered(this.user);
}
