import 'dart:io';

import '../config/config.dart';
import '../core/models.dart';
import 'lock_parser.dart';
import 'pubspec_parser.dart';

class ProjectContext {
  ProjectContext({
    required this.projectDir,
    required this.pubspec,
    required this.lock,
    required this.config,
    required this.packages,
  });

  final Directory projectDir;
  final PubspecInfo pubspec;
  final LockInfo lock;
  final DepGuardConfig config;
  final List<PackageRef> packages;
}

ProjectContext loadProject(Directory projectDir) {
  final config = loadConfig(projectDir);
  final pubspec = parsePubspec(projectDir);
  final lock = parsePubspecLock(projectDir);

  final packages = <PackageRef>[];
  lock.packages.forEach((name, locked) {
    if (config.ignorePackages.contains(name)) {
      return;
    }
    if (pubspec.sdkDependencies.contains(name) || locked.source == 'sdk') {
      return;
    }
    final section = _sectionFor(name, pubspec);
    final isDirect = section != Section.transitive;
    packages.add(
      PackageRef(
        name: name,
        lockedVersion: locked.version,
        section: section,
        isDirect: isDirect,
      ),
    );
  });

  return ProjectContext(
    projectDir: projectDir,
    pubspec: pubspec,
    lock: lock,
    config: config,
    packages: packages,
  );
}

Section _sectionFor(String package, PubspecInfo pubspec) {
  if (pubspec.dependencyOverrides.containsKey(package)) {
    return Section.override;
  }
  if (pubspec.dependencies.containsKey(package)) {
    return Section.prod;
  }
  if (pubspec.devDependencies.containsKey(package)) {
    return Section.dev;
  }
  return Section.transitive;
}
