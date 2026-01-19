import '../core/models.dart';

bool exceedsThreshold(List<Finding> findings, Severity threshold) {
  return findings.any((finding) => finding.severity.index <= threshold.index);
}
