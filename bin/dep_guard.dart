import 'dart:io';

import 'package:dep_guard/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  final runner = DepGuardRunner(
    stdout: stdout,
    stderr: stderr,
  );
  final exitCode = await runner.run(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
