import 'dart:io';

class Logger {
  Logger({
    required this.stderr,
    required this.verbose,
    required this.quiet,
  });

  final IOSink stderr;
  final bool verbose;
  final bool quiet;

  void info(String message) {
    if (verbose) {
      stderr.writeln(message);
    }
  }

  void warn(String message) {
    if (!quiet) {
      stderr.writeln(message);
    }
  }
}

Future<void> writeOutput(
  String content, {
  required IOSink stdout,
  String? outPath,
}) async {
  if (outPath != null && outPath.isNotEmpty) {
    final file = File(outPath);
    file.parent.createSync(recursive: true);
    await file.writeAsString(content);
  } else {
    stdout.write(content);
  }
}
