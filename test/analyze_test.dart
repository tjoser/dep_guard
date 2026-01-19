import 'dart:io';

import 'package:dep_guard/src/checks/analyzer.dart';
import 'package:dep_guard/src/core/models.dart';
import 'package:dep_guard/src/parsing/project_loader.dart';
import 'package:dep_guard/src/pub/pub_client.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'src/fakes.dart';

void main() {
  test('discontinued severity mapping', () async {
    final project = loadProject(Directory('test/fixtures/plain'));
    final fakeClient = FakePubClient(packages: {
      'http': PubPackageInfo(
        name: 'http',
        latestVersion: Version.parse('1.2.1'),
        isDiscontinued: true,
      ),
      'meta': PubPackageInfo(
        name: 'meta',
        latestVersion: Version.parse('1.9.1'),
        isDiscontinued: true,
      ),
      'collection': PubPackageInfo(
        name: 'collection',
        latestVersion: Version.parse('1.18.0'),
      ),
      'test': PubPackageInfo(
        name: 'test',
        latestVersion: Version.parse('1.24.0'),
      ),
    });

    final analyzer = Analyzer(pubClient: fakeClient, allowNetworkFail: true);
    final report = await analyzer.analyze(project, explainScore: false);
    final discontinued = report.findings
        .where((finding) => finding.message.contains('Discontinued'))
        .toList();

    final httpFinding =
        discontinued.firstWhere((finding) => finding.package == 'http');
    final metaFinding =
        discontinued.firstWhere((finding) => finding.package == 'meta');

    expect(httpFinding.severity, Severity.critical);
    expect(metaFinding.severity, Severity.warn);
  });

  test('ignore discontinued rule suppresses findings', () async {
    final project = loadProject(Directory('test/fixtures/sample'));
    final fakeClient = FakePubClient(packages: {
      'http': PubPackageInfo(
        name: 'http',
        latestVersion: Version.parse('1.2.1'),
        isDiscontinued: true,
      ),
      'collection': PubPackageInfo(
        name: 'collection',
        latestVersion: Version.parse('1.18.0'),
      ),
      'test': PubPackageInfo(
        name: 'test',
        latestVersion: Version.parse('1.24.0'),
      ),
      'path': PubPackageInfo(
        name: 'path',
        latestVersion: Version.parse('1.9.0'),
      ),
    });

    final analyzer = Analyzer(pubClient: fakeClient, allowNetworkFail: true);
    final report = await analyzer.analyze(project, explainScore: false);
    final discontinued = report.findings
        .where((finding) => finding.message.contains('Discontinued'))
        .toList();

    expect(discontinued, isEmpty);
  });

  test('network failure without allowNetworkFail throws', () async {
    final project = loadProject(Directory('test/fixtures/plain'));
    final fakeClient = FakePubClient(packages: {}, failed: {'http'});
    final analyzer = Analyzer(pubClient: fakeClient, allowNetworkFail: false);

    expect(
      () => analyzer.analyze(project, explainScore: false),
      throwsA(isA<Exception>()),
    );
  });
}
