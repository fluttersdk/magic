import 'package:magic/src/logging/log_manager.dart';
import 'package:magic/src/logging/contracts/logger_driver.dart';

class MockLogManager extends LogManager {
  final LoggerDriver mockDriver;
  MockLogManager(this.mockDriver);

  @override
  LoggerDriver driver([String? channel]) => mockDriver;
}
