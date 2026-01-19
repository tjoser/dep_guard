import 'package:pub_semver/pub_semver.dart';

enum Severity { critical, warn, info }

enum Section { override, prod, dev, transitive }

enum VersionDelta { patch, minor, major, unknown }

enum PlanBucket { safePatch, safeMinor, riskyMajor, blocked }

class PackageRef {
  PackageRef({
    required this.name,
    required this.lockedVersion,
    required this.section,
    required this.isDirect,
  });

  final String name;
  final Version? lockedVersion;
  final Section section;
  final bool isDirect;

  String sectionLabel() => section.asLabel();
}

extension SectionLabel on Section {
  String asLabel() {
    return switch (this) {
      Section.override => 'override',
      Section.prod => 'prod',
      Section.dev => 'dev',
      Section.transitive => 'transitive',
    };
  }
}

class PubPackageInfo {
  PubPackageInfo({
    required this.name,
    this.latestVersion,
    this.latestPublished,
    this.isDiscontinued = false,
    this.replacedBy,
    this.versions = const [],
  });

  final String name;
  final Version? latestVersion;
  final DateTime? latestPublished;
  final bool isDiscontinued;
  final String? replacedBy;
  final List<Version> versions;
}

class Finding {
  Finding({
    required this.severity,
    required this.package,
    required this.message,
    required this.action,
    required this.locked,
    required this.latest,
    required this.section,
    required this.isDirect,
  });

  final Severity severity;
  final String package;
  final String message;
  final String action;
  final Version? locked;
  final Version? latest;
  final Section section;
  final bool isDirect;
}

class HealthReport {
  HealthReport({
    required this.projectName,
    required this.projectPath,
    required this.findings,
    required this.score,
    required this.duration,
    required this.explainScore,
    required this.summary,
    required this.networkFailures,
  });

  final String projectName;
  final String projectPath;
  final List<Finding> findings;
  final int score;
  final Duration duration;
  final List<String> explainScore;
  final HealthSummary summary;
  final bool networkFailures;
}

class HealthSummary {
  HealthSummary({
    required this.critical,
    required this.warn,
    required this.info,
    required this.directCount,
    required this.transitiveCount,
    required this.sdkConstraint,
  });

  final int critical;
  final int warn;
  final int info;
  final int directCount;
  final int transitiveCount;
  final String sdkConstraint;
}

class PlanStep {
  PlanStep({
    required this.bucket,
    required this.package,
    required this.locked,
    required this.suggestedTarget,
    required this.latestTarget,
    required this.safeTarget,
    required this.delta,
    required this.section,
    required this.isDirect,
    required this.reason,
    required this.action,
    required this.isDiscontinued,
  });

  final PlanBucket bucket;
  final String package;
  final Version? locked;
  final Version? suggestedTarget;
  final Version? latestTarget;
  final Version? safeTarget;
  final VersionDelta delta;
  final Section section;
  final bool isDirect;
  final String reason;
  final String action;
  final bool isDiscontinued;
}

class PlanSummary {
  PlanSummary({
    required this.safePatch,
    required this.safeMinor,
    required this.riskyMajor,
    required this.blocked,
    required this.riskScore,
    required this.duration,
  });

  final int safePatch;
  final int safeMinor;
  final int riskyMajor;
  final int blocked;
  final int riskScore;
  final Duration duration;
}

class UpgradePlan {
  UpgradePlan({
    required this.projectName,
    required this.projectPath,
    required this.steps,
    required this.summary,
    required this.networkFailures,
  });

  final String projectName;
  final String projectPath;
  final List<PlanStep> steps;
  final PlanSummary summary;
  final bool networkFailures;
}

VersionDelta classifyDelta(Version? locked, Version? latest) {
  if (locked == null || latest == null) {
    return VersionDelta.unknown;
  }
  if (latest.major > locked.major) {
    return VersionDelta.major;
  }
  if (latest.major == locked.major && latest.minor > locked.minor) {
    return VersionDelta.minor;
  }
  if (latest.major == locked.major &&
      latest.minor == locked.minor &&
      latest.patch > locked.patch) {
    return VersionDelta.patch;
  }
  return VersionDelta.unknown;
}
