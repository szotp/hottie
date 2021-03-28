import 'package:logging/logging.dart';

final _logger = Logger('hottie');

void logHottie(String message, [Level level = Level.INFO]) {
  _logger.log(level, message);
}
