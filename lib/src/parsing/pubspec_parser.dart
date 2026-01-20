import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class PubspecInfo {
  PubspecInfo({
    required this.name,
    required this.sdkConstraint,
    required this.dependencies,
    required this.devDependencies,
    required this.dependencyOverrides,
    required this.sdkDependencies,
    required this.isFlutter,
  });

  final String name;
  final String sdkConstraint;
  final Map<String, String> dependencies;
  final Map<String, String> devDependencies;
  final Map<String, String> dependencyOverrides;
  final Set<String> sdkDependencies;
  final bool isFlutter;
}

PubspecInfo parsePubspec(Directory projectDir) {
  final file = File(p.join(projectDir.path, 'pubspec.yaml'));
  if (!file.existsSync()) {
    throw StateError('pubspec.yaml not found at ${projectDir.path}');
  }
  final content = file.readAsStringSync();
  final yaml = loadYaml(content);
  if (yaml is! YamlMap) {
    throw StateError('pubspec.yaml is invalid YAML.');
  }
  final name = yaml['name'] is String ? yaml['name'] as String : 'unknown';
  final env = yaml['environment'] is YamlMap ? yaml['environment'] as YamlMap : null;
  final sdkConstraint = env != null && env['sdk'] is String
      ? env['sdk'] as String
      : 'unknown';

  Map<String, String> mapFromYaml(dynamic node, Set<String> sdkPackages) {
    final map = <String, String>{};
    if (node is YamlMap) {
      node.forEach((key, value) {
        if (key is String) {
          if (value is String) {
            map[key] = value;
          } else if (value is YamlMap) {
            final sdk = value['sdk'];
            if (sdk is String) {
              sdkPackages.add(key);
              map[key] = 'sdk';
              return;
            }
            final version = value['version'];
            if (version is String) {
              map[key] = version;
            } else {
              map[key] = 'any';
            }
          } else {
            map[key] = 'any';
          }
        }
      });
    }
    return map;
  }

  final sdkDependencies = <String>{};
  final dependencies = mapFromYaml(yaml['dependencies'], sdkDependencies);
  final devDependencies = mapFromYaml(yaml['dev_dependencies'], sdkDependencies);
  final overrides = mapFromYaml(yaml['dependency_overrides'], sdkDependencies);

  final isFlutter =
      (env != null && env['flutter'] != null) || dependencies.containsKey('flutter');

  return PubspecInfo(
    name: name,
    sdkConstraint: sdkConstraint,
    dependencies: dependencies,
    devDependencies: devDependencies,
    dependencyOverrides: overrides,
    sdkDependencies: sdkDependencies,
    isFlutter: isFlutter,
  );
}
