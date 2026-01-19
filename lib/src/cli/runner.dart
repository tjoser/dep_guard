import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../checks/analyzer.dart';
import '../cli/ci_logic.dart';
import '../core/errors.dart';
import '../core/models.dart';
import '../core/output.dart';
import '../core/version.dart';
import '../parsing/project_loader.dart';
import '../plan/planner.dart';
import '../pub/cache.dart';
import '../pub/pub_client.dart';
import '../report/renderers.dart';

class DepGuardRunner {
  DepGuardRunner({required this.stdout, required this.stderr});

  final IOSink stdout;
  final IOSink stderr;

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>('dep_guard',
        'Dependency health and safe upgrade planning for Dart/Flutter.')
      ..argParser.addFlag(
        'version',
        negatable: false,
        help: 'Print the current version.',
      )
      ..addCommand(AnalyzeCommand(stdout: stdout, stderr: stderr))
      ..addCommand(PlanCommand(stdout: stdout, stderr: stderr))
      ..addCommand(CiCommand(stdout: stdout, stderr: stderr));

    try {
      final argResults = runner.parse(args);
      if (argResults['version'] == true) {
        stdout.writeln('dep_guard $depGuardVersion');
        return 0;
      }
      return await runner.runCommand(argResults) ?? 0;
    } on UsageException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln(e.usage);
      return 64;
    } on DepGuardException catch (e) {
      stderr.writeln('Error: ${e.message}');
      return e.exitCode;
    } catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }
  }
}

class CommonOptions {
  CommonOptions({
    required this.path,
    required this.format,
    required this.out,
    required this.quiet,
    required this.verbose,
    required this.noCache,
    required this.cacheTtlHours,
    required this.timeout,
    required this.retries,
    required this.allowNetworkFail,
  });

  final String path;
  final String format;
  final String? out;
  final bool quiet;
  final bool verbose;
  final bool noCache;
  final int cacheTtlHours;
  final int timeout;
  final int retries;
  final bool allowNetworkFail;
}

abstract class DepGuardCommand extends Command<int> {
  DepGuardCommand({required this.stdout, required this.stderr}) {
    argParser
      ..addOption('path', defaultsTo: '.', help: 'Project directory to analyze.')
      ..addOption(
        'format',
        defaultsTo: 'human',
        help: 'Output format.',
      )
      ..addOption('out', help: 'Write output to file.')
      ..addFlag('quiet', negatable: false, help: 'Reduce output.')
      ..addFlag('verbose', negatable: false, help: 'Verbose diagnostics.')
      ..addFlag('no-cache', negatable: false, help: 'Disable cache.')
      ..addOption(
        'cache-ttl-hours',
        defaultsTo: '24',
        help: 'Cache TTL in hours.',
      )
      ..addOption(
        'timeout',
        defaultsTo: '10',
        help: 'Network timeout in seconds.',
      )
      ..addOption(
        'retries',
        defaultsTo: '2',
        help: 'Network retry count.',
      )
      ..addFlag(
        'allow-network-fail',
        negatable: false,
        help: 'Allow partial results if pub.dev is unreachable.',
      );
  }

  final IOSink stdout;
  final IOSink stderr;

  CommonOptions commonOptions() {
    final format = argResults?['format'] as String? ?? 'human';
    return CommonOptions(
      path: argResults?['path'] as String? ?? '.',
      format: format,
      out: argResults?['out'] as String?,
      quiet: argResults?['quiet'] == true,
      verbose: argResults?['verbose'] == true,
      noCache: argResults?['no-cache'] == true,
      cacheTtlHours: int.tryParse(argResults?['cache-ttl-hours'] as String? ?? '') ??
          24,
      timeout: int.tryParse(argResults?['timeout'] as String? ?? '') ?? 10,
      retries: int.tryParse(argResults?['retries'] as String? ?? '') ?? 2,
      allowNetworkFail: argResults?['allow-network-fail'] == true,
    );
  }

  ProjectContext loadProjectContext(CommonOptions options) {
    final projectDir = Directory(p.normalize(options.path));
    return loadProject(projectDir);
  }

  PubClient createPubClient(CommonOptions options, Directory projectDir) {
    final logger = Logger(
      stderr: stderr,
      verbose: options.verbose,
      quiet: options.quiet,
    );
    final cacheStore = CacheStore(
      ttl: Duration(hours: options.cacheTtlHours),
      enabled: !options.noCache,
      projectDir: projectDir,
    );
    return PubDevClient(
      httpClient: http.Client(),
      cacheStore: cacheStore,
      timeout: Duration(seconds: options.timeout),
      retries: options.retries,
      userAgent: 'dep_guard/$depGuardVersion (dart)',
      logger: logger.info,
    );
  }

  ReportMetadata buildMetadata(
    CommonOptions options, {
    required bool allowNetworkFail,
  }) {
    return ReportMetadata(
      toolVersion: depGuardVersion,
      generatedAt: DateTime.now().toUtc(),
      allowNetworkFail: allowNetworkFail,
      cacheEnabled: !options.noCache,
      cacheTtlHours: options.cacheTtlHours,
      timeoutSeconds: options.timeout,
      retries: options.retries,
    );
  }
}

class AnalyzeCommand extends DepGuardCommand {
  AnalyzeCommand({required super.stdout, required super.stderr}) {
    argParser.addFlag(
      'explain-score',
      negatable: false,
      help: 'Explain health score deductions.',
    );
  }

  @override
  final name = 'analyze';

  @override
  final description = 'Generate a dependency health report.';

  @override
  Future<int> run() async {
    final options = commonOptions();
    if (options.format != 'human' && options.format != 'json') {
      throw UsageException('Unsupported format ${options.format}.', usage);
    }
    final project = loadProjectContext(options);
    final pubClient = createPubClient(options, project.projectDir);
    final analyzer = Analyzer(
      pubClient: pubClient,
      allowNetworkFail: options.allowNetworkFail,
    );
    final report = await analyzer.analyze(
      project,
      explainScore: argResults?['explain-score'] == true,
    );
    final meta = buildMetadata(
      options,
      allowNetworkFail: options.allowNetworkFail,
    );

    final output = options.format == 'json'
        ? renderHealthJson(
            report,
            explainScore: argResults?['explain-score'] == true,
            meta: meta,
          )
        : renderHealthHuman(
            report,
            quiet: options.quiet,
            explainScore: argResults?['explain-score'] == true,
            meta: meta,
          );

    await writeOutput(output, stdout: stdout, outPath: options.out);
    return 0;
  }
}

class PlanCommand extends DepGuardCommand {
  PlanCommand({required super.stdout, required super.stderr}) {
    argParser
      ..addFlag(
        'include-transitive',
        negatable: false,
        help: 'Include transitive dependencies in the plan.',
      )
      ..addOption(
        'max-steps',
        help: 'Limit the number of steps in the plan.',
      );
  }

  @override
  final name = 'plan';

  @override
  final description = 'Generate a safe upgrade plan.';

  @override
  Future<int> run() async {
    final options = commonOptions();
    final includeTransitive = argResults?['include-transitive'] == true;
    final maxSteps = int.tryParse(argResults?['max-steps'] as String? ?? '');

    if (options.format != 'human' &&
        options.format != 'json' &&
        options.format != 'markdown') {
      throw UsageException('Unsupported format ${options.format}.', usage);
    }

    final project = loadProjectContext(options);
    final pubClient = createPubClient(options, project.projectDir);
    final allowNetworkFail = options.allowNetworkFail || options.format == 'human';
    final planner = Planner(
      pubClient: pubClient,
      allowNetworkFail: allowNetworkFail,
    );

    final plan = await planner.plan(
      project,
      includeTransitive: includeTransitive,
    );

    final limitedSteps = maxSteps != null && maxSteps > 0
        ? plan.steps.take(maxSteps).toList()
        : plan.steps;

    final limitedPlan = UpgradePlan(
      projectName: plan.projectName,
      projectPath: plan.projectPath,
      steps: limitedSteps,
      summary: plan.summary,
      networkFailures: plan.networkFailures,
    );
    final meta = buildMetadata(options, allowNetworkFail: allowNetworkFail);

    final output = switch (options.format) {
      'json' => renderPlanJson(limitedPlan, meta: meta),
      'markdown' => renderPlanMarkdown(limitedPlan, meta: meta),
      _ => renderPlanHuman(limitedPlan, meta: meta),
    };

    await writeOutput(output, stdout: stdout, outPath: options.out);
    return 0;
  }
}

class CiCommand extends DepGuardCommand {
  CiCommand({required super.stdout, required super.stderr}) {
    argParser.addOption(
      'fail-on',
      defaultsTo: 'critical',
      allowed: ['critical', 'warn', 'info'],
      help: 'Fail the build at or above this severity.',
    );
  }

  @override
  final name = 'ci';

  @override
  final description = 'Analyze dependencies and fail by severity threshold.';

  @override
  Future<int> run() async {
    final options = commonOptions();
    if (options.format != 'human' && options.format != 'json') {
      throw UsageException('Unsupported format ${options.format}.', usage);
    }
    final project = loadProjectContext(options);
    final pubClient = createPubClient(options, project.projectDir);
    final analyzer = Analyzer(
      pubClient: pubClient,
      allowNetworkFail: options.allowNetworkFail,
    );
    final report = await analyzer.analyze(project, explainScore: false);

    final failOn = argResults?['fail-on'] as String? ?? 'critical';
    final threshold = _severityFromString(failOn);
    final failingFindings = report.findings
        .where((finding) => finding.severity.index <= threshold.index)
        .toList();
    final exceeded = exceedsThreshold(report.findings, threshold);
    final meta = buildMetadata(
      options,
      allowNetworkFail: options.allowNetworkFail,
    );
    final ciSummary = CiSummary(
      threshold: failOn,
      exceeded: exceeded,
      failingCount: failingFindings.length,
    );

    final output = options.format == 'json'
        ? renderHealthJson(
            report,
            explainScore: false,
            meta: meta,
            ci: ciSummary,
          )
        : _renderCiHuman(
            report,
            failingFindings,
            threshold: failOn,
            exceeded: exceeded,
            meta: meta,
          );

    await writeOutput(output, stdout: stdout, outPath: options.out);
    return exceeded ? 2 : 0;
  }
}

Severity _severityFromString(String value) {
  return switch (value) {
    'critical' => Severity.critical,
    'warn' => Severity.warn,
    'info' => Severity.info,
    _ => Severity.critical,
  };
}

String _renderCiHuman(
  HealthReport report,
  List<Finding> failing, {
  required String threshold,
  required bool exceeded,
  ReportMetadata? meta,
}) {
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
  buffer.writeln(
    'Threshold: $threshold | Status: ${exceeded ? 'FAIL' : 'PASS'}',
  );
  if (failing.isNotEmpty) {
    buffer.writeln('Findings:');
    for (final finding in failing) {
      final locked = finding.locked?.toString() ?? 'UNKNOWN';
      final latest = finding.latest?.toString() ?? 'UNKNOWN';
      final direct = finding.isDirect ? 'direct' : 'transitive';
      buffer.writeln(
        '- ${finding.severity.name.toUpperCase()} ${finding.package} '
        '$locked -> $latest ($direct ${finding.section.asLabel()})',
      );
      buffer.writeln('  ${finding.message}');
    }
  }
  buffer.writeln(
    'Health score: ${report.score}/100 | Critical: ${report.summary.critical} '
    'Warn: ${report.summary.warn} Info: ${report.summary.info} | '
    'Duration: ${_formatDuration(report.duration)}',
  );
  return buffer.toString();
}

String _formatDuration(Duration duration) {
  final ms = duration.inMilliseconds;
  if (ms < 1000) {
    return '${ms}ms';
  }
  final seconds = ms / 1000;
  return '${seconds.toStringAsFixed(1)}s';
}
