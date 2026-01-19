import 'package:pub_semver/pub_semver.dart';

import '../core/errors.dart';
import '../core/models.dart';
import '../core/scoring.dart';
import '../parsing/project_loader.dart';
import '../pub/pub_client.dart';

class Analyzer {
  Analyzer({
    required this.pubClient,
    required this.allowNetworkFail,
  });

  final PubClient pubClient;
  final bool allowNetworkFail;

  Future<HealthReport> analyze(
    ProjectContext context, {
    required bool explainScore,
  }) async {
    final start = DateTime.now();
    final packages = context.packages;
    final packageNames = packages.map((pkg) => pkg.name).toSet();
    final result = await pubClient.fetchPackages(packageNames);

    if (result.failed.isNotEmpty && !allowNetworkFail) {
      throw DepGuardException(
        'Failed to reach pub.dev for ${result.failed.length} packages.',
      );
    }

    final findings = <Finding>[];
    final config = context.config;

    if (!config.isRuleIgnored('discontinued')) {
      for (final pkg in packages) {
        final info = result.packages[pkg.name];
        if (info == null) {
          continue;
        }
        if (info.isDiscontinued) {
          final severity = pkg.isDirect ? Severity.critical : Severity.warn;
          final replacement = info.replacedBy != null
              ? ' Replace with ${info.replacedBy}.'
              : '';
          findings.add(
            Finding(
              severity: severity,
              package: pkg.name,
              locked: pkg.lockedVersion,
              latest: info.latestVersion,
              section: pkg.section,
              isDirect: pkg.isDirect,
              message: 'Discontinued on pub.dev.$replacement',
              action: info.replacedBy != null
                  ? 'Switch to ${info.replacedBy}.'
                  : 'Find a maintained replacement.',
            ),
          );
        }
      }
    }

    for (final pkg in packages) {
      final info = result.packages[pkg.name];
      if (info == null) {
        continue;
      }
      final latest = info.latestVersion;
      if (latest == null || pkg.lockedVersion == null) {
        continue;
      }
      if (latest <= pkg.lockedVersion!) {
        continue;
      }
      final delta = classifyDelta(pkg.lockedVersion, latest);
      if (delta == VersionDelta.major && !config.isRuleIgnored('major')) {
        findings.add(
          Finding(
            severity: pkg.isDirect ? Severity.warn : Severity.info,
            package: pkg.name,
            locked: pkg.lockedVersion,
            latest: latest,
            section: pkg.section,
            isDirect: pkg.isDirect,
            message: 'Major version behind.',
            action: 'Plan a migration before upgrading.',
          ),
        );
      } else if (delta == VersionDelta.minor || delta == VersionDelta.patch) {
        findings.add(
          Finding(
            severity: Severity.info,
            package: pkg.name,
            locked: pkg.lockedVersion,
            latest: latest,
            section: pkg.section,
            isDirect: pkg.isDirect,
            message: 'Minor/Patch behind.',
            action: 'Upgrade when convenient.',
          ),
        );
      }
    }

    if (!config.isRuleIgnored('stale_package')) {
      final staleCutoff =
          DateTime.now().subtract(Duration(days: config.staleMonths * 30));
      for (final pkg in packages) {
        final info = result.packages[pkg.name];
        if (info == null || info.latestPublished == null) {
          continue;
        }
        if (info.latestPublished!.isBefore(staleCutoff)) {
          findings.add(
            Finding(
              severity: Severity.warn,
              package: pkg.name,
              locked: pkg.lockedVersion,
              latest: info.latestVersion,
              section: pkg.section,
              isDirect: pkg.isDirect,
              message: 'Stale package (no releases in ${config.staleMonths} months).',
              action: 'Audit maintenance status or pin carefully.',
            ),
          );
        }
      }
    }

    if (!config.isRuleIgnored('risky_constraints')) {
      void checkConstraints(Map<String, String> deps, Section section) {
        deps.forEach((name, constraint) {
          if (config.ignorePackages.contains(name)) {
            return;
          }
          final isAny = constraint.trim() == 'any' || constraint.trim() == '>=0.0.0';
          VersionConstraint? constraintObj;
          try {
            constraintObj = VersionConstraint.parse(constraint);
          } catch (_) {
            constraintObj = null;
          }
          final isOpenEnded = constraintObj is VersionRange &&
              constraintObj.max == null &&
              constraintObj.min != null;
          if (isAny || isOpenEnded) {
            findings.add(
              Finding(
                severity: Severity.warn,
                package: name,
                locked: null,
                latest: null,
                section: section,
                isDirect: true,
                message: 'Risky constraint ($constraint).',
                action: 'Add an upper bound for safer upgrades.',
              ),
            );
          }
        });
      }

      checkConstraints(context.pubspec.dependencies, Section.prod);
      checkConstraints(context.pubspec.devDependencies, Section.dev);
    }

    if (context.pubspec.dependencyOverrides.isNotEmpty &&
        !config.isRuleIgnored('dependency_overrides')) {
      findings.add(
        Finding(
          severity: Severity.warn,
          package: 'dependency_overrides',
          locked: null,
          latest: null,
          section: Section.override,
          isDirect: true,
          message: 'dependency_overrides present.',
          action: 'Remove overrides once resolved.',
        ),
      );
    }

    findings.add(
      Finding(
        severity: Severity.info,
        package: 'project',
        locked: null,
        latest: null,
        section: Section.prod,
        isDirect: true,
        message:
            'Type: ${context.pubspec.isFlutter ? 'Flutter' : 'Dart'} | SDK constraints: ${context.pubspec.sdkConstraint} | Direct deps: ${packages.where((pkg) => pkg.isDirect).length} | Transitive: ${packages.where((pkg) => !pkg.isDirect).length}',
        action: 'Informational.',
      ),
    );

    findings.sort((a, b) => a.package.compareTo(b.package));
    final summary = _summaryFor(findings, context.pubspec.sdkConstraint, packages);
    final scoreResult = calculateScore(findings);

    final duration = DateTime.now().difference(start);
    return HealthReport(
      projectName: context.pubspec.name,
      projectPath: context.projectDir.path,
      findings: findings,
      score: scoreResult.score,
      duration: duration,
      explainScore: explainScore ? scoreResult.explain : const [],
      summary: summary,
      networkFailures: result.failed.isNotEmpty,
    );
  }

  HealthSummary _summaryFor(
    List<Finding> findings,
    String sdkConstraint,
    List<PackageRef> packages,
  ) {
    var critical = 0;
    var warn = 0;
    var info = 0;
    for (final finding in findings) {
      switch (finding.severity) {
        case Severity.critical:
          critical++;
          break;
        case Severity.warn:
          warn++;
          break;
        case Severity.info:
          info++;
          break;
      }
    }
    final directCount = packages.where((pkg) => pkg.isDirect).length;
    final transitiveCount = packages.where((pkg) => !pkg.isDirect).length;
    return HealthSummary(
      critical: critical,
      warn: warn,
      info: info,
      directCount: directCount,
      transitiveCount: transitiveCount,
      sdkConstraint: sdkConstraint,
    );
  }
}
