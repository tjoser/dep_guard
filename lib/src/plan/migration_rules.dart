import '../core/models.dart';

class MigrationHint {
  MigrationHint({required this.reason, required this.action});

  final String reason;
  final String action;
}

abstract class MigrationRule {
  bool matches(PackageRef package, PubPackageInfo info);
  MigrationHint hint(PackageRef package, PubPackageInfo info);
}

class JsDiscontinuedRule implements MigrationRule {
  @override
  bool matches(PackageRef package, PubPackageInfo info) {
    return package.name == 'js' && info.isDiscontinued;
  }

  @override
  MigrationHint hint(PackageRef package, PubPackageInfo info) {
    return MigrationHint(
      reason: 'Package discontinued.',
      action: 'Replace with dart:js_interop.',
    );
  }
}

class ReplacedByRule implements MigrationRule {
  @override
  bool matches(PackageRef package, PubPackageInfo info) {
    return info.replacedBy != null && info.replacedBy!.isNotEmpty;
  }

  @override
  MigrationHint hint(PackageRef package, PubPackageInfo info) {
    return MigrationHint(
      reason: 'Package discontinued.',
      action: 'Replace with ${info.replacedBy}.',
    );
  }
}

class MigrationRulesEngine {
  MigrationRulesEngine({List<MigrationRule>? rules})
      : _rules = rules ?? [JsDiscontinuedRule(), ReplacedByRule()];

  final List<MigrationRule> _rules;

  MigrationHint? match(PackageRef package, PubPackageInfo info) {
    for (final rule in _rules) {
      if (rule.matches(package, info)) {
        return rule.hint(package, info);
      }
    }
    return null;
  }
}
