import 'package:magic/magic.dart';
import '../../models/user.dart';

class UserRegistered extends MagicEvent {
  final User user;
  UserRegistered(this.user);
}
