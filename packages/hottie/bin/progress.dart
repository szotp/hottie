import 'package:hottie/src/utils/logger.dart';

Future<void> main() async {
  logger.info('start');
  final progress = printer.start('test');
  await Future<void>.delayed(const Duration(seconds: 1));
  progress.finish('finished');
}
