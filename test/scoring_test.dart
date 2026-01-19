import 'package:dep_guard/src/core/models.dart';
import 'package:dep_guard/src/core/scoring.dart';
import 'package:test/test.dart';

void main() {
  test('health score deductions', () {
    final findings = [
      Finding(
        rule: FindingRule.discontinued,
        severity: Severity.critical,
        package: 'http',
        message: 'Discontinued on pub.dev.',
        action: 'Replace',
        locked: null,
        latest: null,
        section: Section.prod,
        isDirect: true,
      ),
      Finding(
        rule: FindingRule.stalePackage,
        severity: Severity.warn,
        package: 'meta',
        message: 'Stale package (no releases in 18 months).',
        action: 'Audit',
        locked: null,
        latest: null,
        section: Section.transitive,
        isDirect: false,
      ),
      Finding(
        rule: FindingRule.majorBehind,
        severity: Severity.warn,
        package: 'collection',
        message: 'Major version behind.',
        action: 'Plan',
        locked: null,
        latest: null,
        section: Section.prod,
        isDirect: true,
      ),
    ];

    final result = calculateScore(findings);
    expect(result.score, 100 - 25 - 8 - 6);
  });
}
