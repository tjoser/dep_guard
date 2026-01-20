import 'dart:convert';

import '../core/models.dart';

String renderHealthHuman(
  HealthReport report, {
  required bool quiet,
  required bool explainScore,
  ReportMetadata? meta,
  List<Finding>? findings,
  String? filterNote,
}) {
  final effectiveFindings = findings ?? report.findings;
  final buffer = StringBuffer();
  buffer.writeln(
    'Dependency Health - ${report.projectName} (${report.projectPath})',
  );
  if (meta != null) {
    buffer.writeln(formatReportMetadata(meta));
  }
  buffer.writeln(
    'Type: ${report.summary.projectType} | SDK constraints: ${report.summary.sdkConstraint} '
    '| Direct deps: ${report.summary.directCount} | Transitive: ${report.summary.transitiveCount}',
  );
  if (report.networkFailures) {
    buffer.writeln('Warning: pub.dev unavailable for some packages.');
  }
  if (filterNote != null) {
    buffer.writeln(filterNote);
  }
  buffer.writeln();

  final grouped = <Severity, List<Finding>>{
    Severity.critical: [],
    Severity.warn: [],
    Severity.info: [],
  };
  for (final finding in effectiveFindings) {
    grouped[finding.severity]!.add(finding);
  }

  void writeSection(Severity severity, String label) {
    final items = grouped[severity]!;
    if (items.isEmpty) {
      return;
    }
    if (quiet && severity == Severity.info) {
      return;
    }
    buffer.writeln('${label.toUpperCase()} (${items.length})');
    for (final item in items) {
      final locked = item.locked?.toString() ?? 'UNKNOWN';
      final latest = item.latest?.toString() ?? 'UNKNOWN';
      final direct = item.isDirect ? 'direct' : 'transitive';
      buffer.writeln(
        '  ${item.package} $locked -> $latest ($direct ${item.section.asLabel()})',
      );
      buffer.writeln('  ${item.message}');
      buffer.writeln('  Action: ${item.action}');
      buffer.writeln();
    }
  }

  writeSection(Severity.critical, 'Critical');
  writeSection(Severity.warn, 'Warn');
  writeSection(Severity.info, 'Info');

  if (explainScore && report.explainScore.isNotEmpty) {
    buffer.writeln('Score breakdown:');
    for (final line in report.explainScore) {
      buffer.writeln('  $line');
    }
  }

  buffer.writeln(
    'Health score: ${report.score}/100 | Critical: ${report.summary.critical} '
    'Warn: ${report.summary.warn} Info: ${report.summary.info} | '
    'Duration: ${_formatDuration(report.duration)}',
  );

  return buffer.toString();
}

String renderHealthCompact(
  HealthReport report, {
  required bool quiet,
  required bool explainScore,
  ReportMetadata? meta,
  List<Finding>? findings,
  String? filterNote,
}) {
  final effectiveFindings = findings ?? report.findings;
  final buffer = StringBuffer();
  buffer.writeln(
    'Dependency Health - ${report.projectName} (${report.projectPath})',
  );
  if (meta != null) {
    buffer.writeln(formatReportMetadata(meta));
  }
  buffer.writeln(
    'Type: ${report.summary.projectType} | SDK constraints: ${report.summary.sdkConstraint} '
    '| Direct deps: ${report.summary.directCount} | Transitive: ${report.summary.transitiveCount}',
  );
  if (report.networkFailures) {
    buffer.writeln('Warning: pub.dev unavailable for some packages.');
  }
  if (filterNote != null) {
    buffer.writeln(filterNote);
  }
  buffer.writeln();

  final grouped = <Severity, List<Finding>>{
    Severity.critical: [],
    Severity.warn: [],
    Severity.info: [],
  };
  for (final finding in effectiveFindings) {
    grouped[finding.severity]!.add(finding);
  }

  void writeSection(Severity severity, String label) {
    final items = grouped[severity]!;
    if (items.isEmpty) {
      return;
    }
    if (quiet && severity == Severity.info) {
      return;
    }
    buffer.writeln('${label.toUpperCase()} (${items.length})');
    for (final item in items) {
      final locked = item.locked?.toString() ?? 'UNKNOWN';
      final latest = item.latest?.toString() ?? 'UNKNOWN';
      final direct = item.isDirect ? 'direct' : 'transitive';
      buffer.writeln(
        '- ${item.package} $locked -> $latest ($direct ${item.section.asLabel()}) | ${item.message}',
      );
    }
  }

  writeSection(Severity.critical, 'Critical');
  writeSection(Severity.warn, 'Warn');
  writeSection(Severity.info, 'Info');

  if (explainScore && report.explainScore.isNotEmpty) {
    buffer.writeln('Score breakdown:');
    for (final line in report.explainScore) {
      buffer.writeln('  $line');
    }
  }

  buffer.writeln(
    'Health score: ${report.score}/100 | Critical: ${report.summary.critical} '
    'Warn: ${report.summary.warn} Info: ${report.summary.info} | '
    'Duration: ${_formatDuration(report.duration)}',
  );

  return buffer.toString();
}

String renderHealthJson(
  HealthReport report, {
  required bool explainScore,
  ReportMetadata? meta,
  CiSummary? ci,
  List<Finding>? findings,
  Map<String, Object?>? filters,
}) {
  final effectiveFindings = findings ?? report.findings;
  final findingsList = effectiveFindings
      .map((finding) => {
            'rule': finding.rule,
            'severity': finding.severity.name,
            'package': finding.package,
            'locked': finding.locked?.toString(),
            'latest': finding.latest?.toString(),
            'direct': finding.isDirect,
            'section': finding.section.asLabel(),
            'message': finding.message,
            'action': finding.action,
          })
      .toList();

  final jsonMap = <String, dynamic>{
    'project': {
      'name': report.projectName,
      'path': report.projectPath,
      'type': report.summary.projectType,
      'sdkConstraint': report.summary.sdkConstraint,
    },
    'summary': {
      'healthScore': report.score,
      'critical': report.summary.critical,
      'warn': report.summary.warn,
      'info': report.summary.info,
      'direct': report.summary.directCount,
      'transitive': report.summary.transitiveCount,
      'durationMs': report.duration.inMilliseconds,
      'networkFailures': report.networkFailures,
    },
    'findings': findingsList,
  };

  if (meta != null) {
    jsonMap['meta'] = meta.toJson();
  }
  if (ci != null) {
    jsonMap['ci'] = ci.toJson();
  }
  if (filters != null) {
    jsonMap['filters'] = filters;
  }
  if (explainScore) {
    jsonMap['scoreBreakdown'] = report.explainScore;
  }

  return const JsonEncoder.withIndent('  ').convert(jsonMap);
}

String renderPlanHuman(UpgradePlan plan, {ReportMetadata? meta}) {
  final buffer = StringBuffer();
  buffer.writeln('Safe Upgrade Plan - ${plan.projectName} (${plan.projectPath})');
  if (meta != null) {
    buffer.writeln(formatReportMetadata(meta));
  }
  if (plan.networkFailures) {
    buffer.writeln('Warning: pub.dev unavailable for some packages.');
  }
  buffer.writeln();

  void writeBucket(PlanBucket bucket, String label) {
    final items = plan.steps.where((step) => step.bucket == bucket).toList();
    buffer.writeln(label);
    if (items.isEmpty) {
      buffer.writeln('  (none)');
      buffer.writeln();
      return;
    }
    for (final step in items) {
      final locked = step.locked?.toString() ?? 'UNKNOWN';
      final suggested = (step.suggestedTarget ?? step.latestTarget)?.toString() ??
          'UNKNOWN';
      final direct = step.isDirect ? 'direct' : 'transitive';
      buffer.writeln(
        '  ${step.package} $locked -> $suggested ($direct ${step.section.asLabel()})',
      );
      if (step.delta == VersionDelta.major) {
        buffer.writeln(
          '  Safe target: ${step.safeTarget?.toString() ?? 'UNKNOWN'}',
        );
        buffer.writeln(
          '  Latest target: ${step.latestTarget?.toString() ?? 'UNKNOWN'}',
        );
      }
      buffer.writeln('  Reason: ${step.reason}');
      buffer.writeln('  Action: ${step.action}');
      buffer.writeln();
    }
  }

  writeBucket(PlanBucket.safePatch, 'STEP 1 - Safe (Patch)');
  writeBucket(PlanBucket.safeMinor, 'STEP 2 - Safe (Minor)');
  writeBucket(PlanBucket.riskyMajor, 'STEP 3 - Risky (Major)');
  writeBucket(PlanBucket.blocked, 'STEP 4 - Blocked (Discontinued)');

  buffer.writeln(
    'Summary: Patch ${plan.summary.safePatch} | Minor ${plan.summary.safeMinor} '
    '| Major ${plan.summary.riskyMajor} | Blocked ${plan.summary.blocked} '
    '| Risk score: ${plan.summary.riskScore} | Duration: ${_formatDuration(plan.summary.duration)}',
  );

  return buffer.toString();
}

String renderPlanMarkdown(UpgradePlan plan, {ReportMetadata? meta}) {
  final buffer = StringBuffer();
  buffer.writeln('## Safe Upgrade Plan - ${plan.projectName}');
  if (meta != null) {
    buffer.writeln();
    buffer.writeln(formatReportMetadata(meta));
  }
  buffer.writeln();

  void writeBucket(PlanBucket bucket, String label) {
    final items = plan.steps.where((step) => step.bucket == bucket).toList();
    buffer.writeln('**$label**');
    if (items.isEmpty) {
      buffer.writeln('- [ ] _(none)_');
      buffer.writeln();
      return;
    }
    for (final step in items) {
      final locked = step.locked?.toString() ?? 'UNKNOWN';
      final suggested = (step.suggestedTarget ?? step.latestTarget)?.toString() ??
          'UNKNOWN';
      final direct = step.isDirect ? 'direct' : 'transitive';
      buffer.writeln(
        '- [ ] `${step.package}` $locked -> $suggested ($direct ${step.section.asLabel()})',
      );
      if (step.delta == VersionDelta.major) {
        buffer.writeln(
          '  - Safe target: ${step.safeTarget?.toString() ?? 'UNKNOWN'}',
        );
        buffer.writeln(
          '  - Latest target: ${step.latestTarget?.toString() ?? 'UNKNOWN'}',
        );
      }
      buffer.writeln('  - Reason: ${step.reason}');
      buffer.writeln('  - Action: ${step.action}');
    }
    buffer.writeln();
  }

  writeBucket(PlanBucket.safePatch, 'STEP 1 - Safe (Patch)');
  writeBucket(PlanBucket.safeMinor, 'STEP 2 - Safe (Minor)');
  writeBucket(PlanBucket.riskyMajor, 'STEP 3 - Risky (Major)');
  writeBucket(PlanBucket.blocked, 'STEP 4 - Blocked (Discontinued)');

  buffer.writeln(
    '**Summary:** Patch ${plan.summary.safePatch} | Minor ${plan.summary.safeMinor} '
    '| Major ${plan.summary.riskyMajor} | Blocked ${plan.summary.blocked} '
    '| Risk score: ${plan.summary.riskScore} | Duration: ${_formatDuration(plan.summary.duration)}',
  );

  return buffer.toString();
}

String renderPlanJson(UpgradePlan plan, {ReportMetadata? meta}) {
  final steps = plan.steps
      .map((step) => {
            'bucket': _bucketName(step.bucket),
            'package': step.package,
            'locked': step.locked?.toString(),
            'suggestedTarget': step.suggestedTarget?.toString(),
            'latestTarget': step.latestTarget?.toString(),
            'safeTarget': step.safeTarget?.toString(),
            'delta': step.delta.name,
            'direct': step.isDirect,
            'section': step.section.asLabel(),
            'reason': step.reason,
            'action': step.action,
            'discontinued': step.isDiscontinued,
          })
      .toList();

  final jsonMap = {
    'project': {
      'name': plan.projectName,
      'path': plan.projectPath,
    },
    'summary': {
      'safePatch': plan.summary.safePatch,
      'safeMinor': plan.summary.safeMinor,
      'riskyMajor': plan.summary.riskyMajor,
      'blocked': plan.summary.blocked,
      'riskScore': plan.summary.riskScore,
      'durationMs': plan.summary.duration.inMilliseconds,
      'networkFailures': plan.networkFailures,
    },
    'steps': steps,
  };

  if (meta != null) {
    jsonMap['meta'] = meta.toJson();
  }

  return const JsonEncoder.withIndent('  ').convert(jsonMap);
}

String _bucketName(PlanBucket bucket) {
  return switch (bucket) {
    PlanBucket.safePatch => 'safe_patch',
    PlanBucket.safeMinor => 'safe_minor',
    PlanBucket.riskyMajor => 'risky_major',
    PlanBucket.blocked => 'blocked',
  };
}

String _formatDuration(Duration duration) {
  final ms = duration.inMilliseconds;
  if (ms < 1000) {
    return '${ms}ms';
  }
  final seconds = ms / 1000;
  return '${seconds.toStringAsFixed(1)}s';
}

String formatReportMetadata(ReportMetadata meta) {
  final cache = meta.cacheEnabled
      ? 'enabled (${meta.cacheTtlHours}h)'
      : 'disabled';
  return 'Generated: ${meta.generatedAt.toIso8601String()} | Tool: dep_guard ${meta.toolVersion} '
      '| Cache: $cache | Network: timeout ${meta.timeoutSeconds}s, retries ${meta.retries} '
      '| Allow network fail: ${meta.allowNetworkFail}';
}
