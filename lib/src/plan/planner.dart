import 'package:pub_semver/pub_semver.dart';

import '../core/errors.dart';
import '../core/models.dart';
import '../parsing/project_loader.dart';
import '../pub/pub_client.dart';
import 'migration_rules.dart';

class Planner {
  Planner({
    required this.pubClient,
    required this.allowNetworkFail,
    MigrationRulesEngine? rulesEngine,
  }) : _rules = rulesEngine ?? MigrationRulesEngine();

  final PubClient pubClient;
  final bool allowNetworkFail;
  final MigrationRulesEngine _rules;

  Future<UpgradePlan> plan(
    ProjectContext context, {
    required bool includeTransitive,
  }) async {
    final start = DateTime.now();
    final packages = context.packages
        .where((pkg) => includeTransitive || pkg.isDirect)
        .toList();
    final packageNames = packages.map((pkg) => pkg.name).toSet();
    final result = await pubClient.fetchPackages(packageNames);

    if (result.failed.isNotEmpty && !allowNetworkFail) {
      throw DepGuardException(
        'Failed to reach pub.dev for ${result.failed.length} packages.',
      );
    }

    final steps = <PlanStep>[];
    for (final pkg in packages) {
      if (context.config.ignorePackages.contains(pkg.name)) {
        continue;
      }
      final info = result.packages[pkg.name];
      final latest = info?.latestVersion;
      final locked = pkg.lockedVersion;

      var isDiscontinued = info?.isDiscontinued ?? false;
      if (context.config.isRuleIgnored('discontinued')) {
        isDiscontinued = false;
      }

      if (isDiscontinued) {
        final hint = info != null ? _rules.match(pkg, info) : null;
        steps.add(
          PlanStep(
            bucket: PlanBucket.blocked,
            package: pkg.name,
            locked: locked,
            suggestedTarget: null,
            latestTarget: latest,
            safeTarget: null,
            delta: VersionDelta.unknown,
            section: pkg.section,
            isDirect: pkg.isDirect,
            reason: hint?.reason ?? 'Package discontinued.',
            action: hint?.action ?? 'Find a maintained replacement.',
            isDiscontinued: true,
          ),
        );
        continue;
      }

      final delta = classifyDelta(locked, latest);
      if (delta == VersionDelta.unknown && latest == null) {
        steps.add(
          PlanStep(
            bucket: PlanBucket.safePatch,
            package: pkg.name,
            locked: locked,
            suggestedTarget: null,
            latestTarget: null,
            safeTarget: null,
            delta: VersionDelta.unknown,
            section: pkg.section,
            isDirect: pkg.isDirect,
            reason: 'Latest version UNKNOWN (network unavailable).',
            action: 'Retry when pub.dev is reachable.',
            isDiscontinued: false,
          ),
        );
        continue;
      }

      if (latest == null || locked == null) {
        continue;
      }
      if (latest <= locked) {
        continue;
      }

      if (delta == VersionDelta.major && context.config.isRuleIgnored('major')) {
        continue;
      }

      Version? safeTarget;
      if (delta == VersionDelta.major && info != null && info.versions.isNotEmpty) {
        safeTarget = _latestWithinMajor(info.versions, locked.major);
      }

      final bucket = switch (delta) {
        VersionDelta.patch => PlanBucket.safePatch,
        VersionDelta.minor => PlanBucket.safeMinor,
        VersionDelta.major => PlanBucket.riskyMajor,
        VersionDelta.unknown => PlanBucket.safePatch,
      };

      final reason = switch (delta) {
        VersionDelta.patch => 'Patch update available.',
        VersionDelta.minor => 'Minor update available.',
        VersionDelta.major => 'Major update available. Breaking changes likely.',
        VersionDelta.unknown => 'Update available.',
      };

      final action = delta == VersionDelta.major
          ? 'Review changelog and plan migration.'
          : 'Upgrade when ready.';

      steps.add(
        PlanStep(
          bucket: bucket,
          package: pkg.name,
          locked: locked,
          suggestedTarget: delta == VersionDelta.major ? safeTarget : latest,
          latestTarget: latest,
          safeTarget: safeTarget,
          delta: delta,
          section: pkg.section,
          isDirect: pkg.isDirect,
          reason: reason,
          action: action,
          isDiscontinued: false,
        ),
      );
    }

    steps.sort(_planStepComparator);

    final summary = PlanSummary(
      safePatch: steps.where((s) => s.bucket == PlanBucket.safePatch).length,
      safeMinor: steps.where((s) => s.bucket == PlanBucket.safeMinor).length,
      riskyMajor: steps.where((s) => s.bucket == PlanBucket.riskyMajor).length,
      blocked: steps.where((s) => s.bucket == PlanBucket.blocked).length,
      riskScore: _riskScore(steps),
      duration: DateTime.now().difference(start),
    );

    return UpgradePlan(
      projectName: context.pubspec.name,
      projectPath: context.projectDir.path,
      steps: steps,
      summary: summary,
      networkFailures: result.failed.isNotEmpty,
    );
  }

  Version? _latestWithinMajor(List<Version> versions, int major) {
    final candidates = versions.where((v) => v.major == major).toList();
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) => a.compareTo(b));
    return candidates.last;
  }

  int _riskScore(List<PlanStep> steps) {
    var score = 0;
    for (final step in steps) {
      switch (step.bucket) {
        case PlanBucket.safePatch:
          score += 1;
          break;
        case PlanBucket.safeMinor:
          score += 2;
          break;
        case PlanBucket.riskyMajor:
          score += 5;
          break;
        case PlanBucket.blocked:
          score += 8;
          break;
      }
    }
    return score;
  }
}

int _planStepComparator(PlanStep a, PlanStep b) {
  final bucketOrder = {
    PlanBucket.safePatch: 0,
    PlanBucket.safeMinor: 1,
    PlanBucket.riskyMajor: 2,
    PlanBucket.blocked: 3,
  };
  final sectionOrder = {
    Section.override: 0,
    Section.prod: 1,
    Section.dev: 2,
    Section.transitive: 3,
  };
  final bucketCompare =
      bucketOrder[a.bucket]!.compareTo(bucketOrder[b.bucket]!);
  if (bucketCompare != 0) {
    return bucketCompare;
  }
  final sectionCompare =
      sectionOrder[a.section]!.compareTo(sectionOrder[b.section]!);
  if (sectionCompare != 0) {
    return sectionCompare;
  }
  return a.package.compareTo(b.package);
}
