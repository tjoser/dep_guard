import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class DepGuardConfig {
  DepGuardConfig({
    required this.ignorePackages,
    required this.ignoreRules,
    required this.staleMonths,
  });

  final Set<String> ignorePackages;
  final Set<String> ignoreRules;
  final int staleMonths;

  bool isRuleIgnored(String rule) => ignoreRules.contains(rule);

  static DepGuardConfig defaults() {
    return DepGuardConfig(
      ignorePackages: <String>{},
      ignoreRules: <String>{},
      staleMonths: 18,
    );
  }
}

DepGuardConfig loadConfig(Directory projectDir) {
  final configFile = File(p.join(projectDir.path, '.dep_guard.yaml'));
  if (!configFile.existsSync()) {
    return DepGuardConfig.defaults();
  }
  try {
    final content = configFile.readAsStringSync();
    final yaml = loadYaml(content);
    if (yaml is! YamlMap) {
      return DepGuardConfig.defaults();
    }
    final ignore = yaml['ignore'] is YamlMap ? yaml['ignore'] as YamlMap : null;
    final ignorePackages = <String>{};
    final ignoreRules = <String>{};
    if (ignore != null) {
      final packages = ignore['packages'];
      if (packages is YamlList) {
        ignorePackages.addAll(packages.whereType<String>());
      }
      final rules = ignore['rules'];
      if (rules is YamlList) {
        ignoreRules.addAll(rules.whereType<String>());
      }
    }
    final thresholds =
        yaml['thresholds'] is YamlMap ? yaml['thresholds'] as YamlMap : null;
    var staleMonths = 18;
    if (thresholds != null && thresholds['stale_months'] is int) {
      staleMonths = thresholds['stale_months'] as int;
    }
    return DepGuardConfig(
      ignorePackages: ignorePackages,
      ignoreRules: ignoreRules,
      staleMonths: staleMonths,
    );
  } catch (_) {
    return DepGuardConfig.defaults();
  }
}
