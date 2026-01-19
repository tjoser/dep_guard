class DepGuardException implements Exception {
  DepGuardException(this.message, {this.exitCode = 1});

  final String message;
  final int exitCode;

  @override
  String toString() => message;
}
