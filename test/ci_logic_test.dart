import 'package:dep_guard/src/cli/ci_logic.dart';
import 'package:dep_guard/src/core/models.dart';
import 'package:test/test.dart';

void main() {
  test('ci threshold exit logic', () {
    final findings = [
      Finding(
        rule: FindingRule.majorBehind,
        severity: Severity.warn,
        package: 'http',
        message: 'Warn',
        action: 'Fix',
        locked: null,
        latest: null,
        section: Section.prod,
        isDirect: true,
      ),
    ];

    expect(exceedsThreshold(findings, Severity.critical), isFalse);
    expect(exceedsThreshold(findings, Severity.warn), isTrue);
  });
}
