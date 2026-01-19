import 'package:pub_semver/pub_semver.dart';

enum Severity { critical, warn, info }

enum Section { override, prod, dev, transitive }

enum VersionDelta { patch, minor, major, unknown }

enum PlanBucket { safePatch, safeMinor, riskyMajor, blocked }

class FindingRule {
  static const String discontinued = 'discontinued';
  static const String stalePackage = 'stale_package';
  static const String majorBehind = 'major_behind';
  static const String minorPatchBehind = 'minor_patch_behind';
  static const String riskyConstraints = 'risky_constraints';
  static const String dependencyOverrides = 'dependency_overrides';
}

class ReportMetadata {
  ReportMetadata({
    required this.toolVersion,
    required this.generatedAt,
    required this.allowNetworkFail,
    required this.cacheEnabled,
    required this.cacheTtlHours,
    required this.timeoutSeconds,
    required this.retries,
  });

  final String toolVersion;
  final DateTime generatedAt;
  final bool allowNetworkFail;
  final bool cacheEnabled;
  final int cacheTtlHours;
  final int timeoutSeconds;
  final int retries;

  Map<String, Object> toJson() {
    return {
      'toolVersion': toolVersion,
      'generatedAt': generatedAt.toIso8601String(),
      'allowNetworkFail': allowNetworkFail,
      'cache': {
        'enabled': cacheEnabled,
        'ttlHours': cacheTtlHours,
      },
      'network': {
        'timeoutSeconds': timeoutSeconds,
        'retries': retries,
      },
    };
  }
}

class CiSummary {
  CiSummary({
    required this.threshold,
    required this.exceeded,
    required this.failingCount,
  });

  final String threshold;
  final bool exceeded;
  final int failingCount;

  Map<String, Object> toJson() {
    return {
      'threshold': threshold,
      'exceeded': exceeded,
      'failingCount': failingCount,
    };
  }
}

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
    required this.rule,
    required this.severity,
    required this.package,
    required this.message,
    required this.action,
    required this.locked,
    required this.latest,
    required this.section,
    required this.isDirect,
  });

  final String rule;
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
    required this.projectType,
  });

  final int critical;
  final int warn;
  final int info;
  final int directCount;
  final int transitiveCount;
  final String sdkConstraint;
  final String projectType;
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
