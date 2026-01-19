import 'models.dart';

class ScoreResult {
  ScoreResult({
    required this.score,
    required this.explain,
  });

  final int score;
  final List<String> explain;
}

ScoreResult calculateScore(List<Finding> findings) {
  var score = 100;
  final explain = <String>[];

  void apply(int delta, String reason) {
    score -= delta;
    explain.add('-$delta $reason');
  }

  for (final finding in findings) {
    switch (finding.rule) {
      case FindingRule.discontinued:
        if (finding.isDirect) {
          apply(25, '${finding.package} discontinued (direct)');
        } else {
          apply(10, '${finding.package} discontinued (transitive)');
        }
        break;
      case FindingRule.stalePackage:
        apply(8, '${finding.package} stale');
        break;
      case FindingRule.majorBehind:
        if (finding.isDirect) {
          apply(6, '${finding.package} major behind');
        }
        break;
      case FindingRule.minorPatchBehind:
        if (finding.isDirect) {
          apply(2, '${finding.package} minor/patch behind');
        }
        break;
      default:
        break;
    }
  }

  if (score < 0) {
    score = 0;
  }
  if (score > 100) {
    score = 100;
  }

  return ScoreResult(score: score, explain: explain);
}
