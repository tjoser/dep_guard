import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

class LockedPackage {
  LockedPackage({
    required this.name,
    required this.version,
  });

  final String name;
  final Version? version;
}

class LockInfo {
  LockInfo({
    required this.packages,
  });

  final Map<String, LockedPackage> packages;
}

Version? _tryParseVersion(String raw) {
  try {
    return Version.parse(raw);
  } on FormatException {
    return null;
  }
}

LockInfo parsePubspecLock(Directory projectDir) {
  final file = File(p.join(projectDir.path, 'pubspec.lock'));
  if (!file.existsSync()) {
    throw StateError(
      'pubspec.lock not found. Run "dart pub get" or "flutter pub get" first.',
    );
  }
  final content = file.readAsStringSync();
  final yaml = loadYaml(content);
  if (yaml is! YamlMap) {
    throw StateError('pubspec.lock is invalid YAML.');
  }
  final packagesNode = yaml['packages'];
  if (packagesNode is! YamlMap) {
    throw StateError('pubspec.lock is missing packages.');
  }
  final packages = <String, LockedPackage>{};
  packagesNode.forEach((key, value) {
    if (key is! String || value is! YamlMap) {
      return;
    }
    final versionRaw = value['version'];
    Version? version;
    if (versionRaw is String) {
      version = _tryParseVersion(versionRaw);
    }
    packages[key] = LockedPackage(name: key, version: version);
  });
  return LockInfo(packages: packages);
}
