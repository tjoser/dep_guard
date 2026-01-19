import 'dart:io';

import 'package:dep_guard/src/core/models.dart';
import 'package:dep_guard/src/parsing/project_loader.dart';
import 'package:dep_guard/src/plan/planner.dart';
import 'package:dep_guard/src/report/renderers.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'src/fakes.dart';

void main() {
  test('plan bucketing and ordering', () async {
    final project = loadProject(Directory('test/fixtures/overrides'));
    final fakeClient = FakePubClient(packages: {
      'alpha': PubPackageInfo(
        name: 'alpha',
        latestVersion: Version.parse('1.1.0'),
        versions: [Version.parse('1.1.0')],
      ),
      'beta': PubPackageInfo(
        name: 'beta',
        latestVersion: Version.parse('2.0.0'),
        versions: [Version.parse('1.0.0'), Version.parse('2.0.0')],
      ),
      'gamma': PubPackageInfo(
        name: 'gamma',
        latestVersion: Version.parse('1.0.1'),
        versions: [Version.parse('1.0.1')],
      ),
      'delta': PubPackageInfo(
        name: 'delta',
        latestVersion: Version.parse('1.0.1'),
        versions: [Version.parse('1.0.1')],
      ),
      'epsilon': PubPackageInfo(
        name: 'epsilon',
        latestVersion: Version.parse('1.1.0'),
        versions: [Version.parse('1.1.0')],
      ),
    });

    final planner = Planner(pubClient: fakeClient, allowNetworkFail: true);
    final plan = await planner.plan(project, includeTransitive: true);

    expect(plan.steps.first.bucket, PlanBucket.safePatch);
    final safePatch = plan.steps.where((step) => step.bucket == PlanBucket.safePatch).toList();
    expect(safePatch.first.package, 'gamma');
    expect(safePatch[1].package, 'delta');

    final riskyMajor = plan.steps.where((step) => step.bucket == PlanBucket.riskyMajor).toList();
    expect(riskyMajor.single.package, 'beta');
  });

  test('markdown output snapshot', () {
    final plan = UpgradePlan(
      projectName: 'demo',
      projectPath: '/path',
      steps: [
        PlanStep(
          bucket: PlanBucket.safePatch,
          package: 'alpha',
          locked: Version.parse('1.0.0'),
          suggestedTarget: Version.parse('1.0.1'),
          latestTarget: Version.parse('1.0.1'),
          safeTarget: null,
          delta: VersionDelta.patch,
          section: Section.prod,
          isDirect: true,
          reason: 'Patch update available.',
          action: 'Upgrade when ready.',
          isDiscontinued: false,
        ),
      ],
      summary: PlanSummary(
        safePatch: 1,
        safeMinor: 0,
        riskyMajor: 0,
        blocked: 0,
        riskScore: 1,
        duration: const Duration(milliseconds: 500),
      ),
      networkFailures: false,
    );

    final output = renderPlanMarkdown(plan);
    expect(output, contains('## Safe Upgrade Plan - demo'));
    expect(output, contains('`alpha` 1.0.0 -> 1.0.1'));
  });

  test('json output schema keys', () {
    final plan = UpgradePlan(
      projectName: 'demo',
      projectPath: '/path',
      steps: const [],
      summary: PlanSummary(
        safePatch: 0,
        safeMinor: 0,
        riskyMajor: 0,
        blocked: 0,
        riskScore: 0,
        duration: Duration.zero,
      ),
      networkFailures: false,
    );
    final json = renderPlanJson(plan);
    expect(json, contains('"project"'));
    expect(json, contains('"summary"'));
    expect(json, contains('"steps"'));
  });

  test('planner throws on network failure when not allowed', () async {
    final project = loadProject(Directory('test/fixtures/plain'));
    final fakeClient = FakePubClient(packages: {}, failed: {'http'});
    final planner = Planner(pubClient: fakeClient, allowNetworkFail: false);

    expect(
      () => planner.plan(project, includeTransitive: false),
      throwsA(isA<Exception>()),
    );
  });
}
