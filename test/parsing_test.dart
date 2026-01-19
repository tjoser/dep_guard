import 'dart:io';

import 'package:dep_guard/src/core/models.dart';
import 'package:dep_guard/src/parsing/lock_parser.dart';
import 'package:dep_guard/src/parsing/project_loader.dart';
import 'package:dep_guard/src/parsing/pubspec_parser.dart';
import 'package:test/test.dart';

void main() {
  final fixtureDir = Directory('test/fixtures/sample');
  final plainFixtureDir = Directory('test/fixtures/plain');
  final overridesFixtureDir = Directory('test/fixtures/overrides');

  test('parse pubspec.yaml', () {
    final pubspec = parsePubspec(fixtureDir);
    expect(pubspec.name, 'sample_app');
    expect(pubspec.dependencies.keys, containsAll(['http', 'collection']));
    expect(pubspec.devDependencies.keys, contains('test'));
    expect(pubspec.dependencyOverrides.keys, contains('path'));
    expect(pubspec.isFlutter, isFalse);
  });

  test('parse pubspec.lock', () {
    final lock = parsePubspecLock(fixtureDir);
    expect(lock.packages.keys, containsAll(['http', 'collection', 'meta']));
  });

  test('classify direct vs transitive', () {
    final project = loadProject(plainFixtureDir);
    final http = project.packages.firstWhere((p) => p.name == 'http');
    final meta = project.packages.firstWhere((p) => p.name == 'meta');

    expect(http.isDirect, isTrue);
    expect(http.section, Section.prod);
    expect(meta.isDirect, isFalse);
    expect(meta.section, Section.transitive);
  });

  test('classify dependency overrides', () {
    final project = loadProject(overridesFixtureDir);
    final gamma = project.packages.firstWhere((p) => p.name == 'gamma');

    expect(gamma.section, Section.override);
  });

  test('ignore packages from config', () {
    final project = loadProject(fixtureDir);
    expect(project.packages.any((pkg) => pkg.name == 'meta'), isFalse);
  });
}
