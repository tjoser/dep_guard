import 'package:dep_guard/src/core/models.dart';
import 'package:dep_guard/src/report/renderers.dart';
import 'package:test/test.dart';

void main() {
  test('analyze json output schema keys', () {
    final report = HealthReport(
      projectName: 'demo',
      projectPath: '/path',
      findings: const [],
      score: 100,
      duration: const Duration(milliseconds: 10),
      explainScore: const [],
      summary: HealthSummary(
        critical: 0,
        warn: 0,
        info: 0,
        directCount: 0,
        transitiveCount: 0,
        sdkConstraint: '>=3.0.0 <4.0.0',
      ),
      networkFailures: false,
    );

    final json = renderHealthJson(report, explainScore: false);
    expect(json, contains('"project"'));
    expect(json, contains('"summary"'));
    expect(json, contains('"findings"'));
  });
}
