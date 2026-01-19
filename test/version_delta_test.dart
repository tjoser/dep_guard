import 'package:dep_guard/src/core/models.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  test('classify version delta', () {
    expect(
      classifyDelta(Version.parse('1.2.3'), Version.parse('1.2.4')),
      VersionDelta.patch,
    );
    expect(
      classifyDelta(Version.parse('1.2.3'), Version.parse('1.3.0')),
      VersionDelta.minor,
    );
    expect(
      classifyDelta(Version.parse('1.2.3'), Version.parse('2.0.0')),
      VersionDelta.major,
    );
    expect(classifyDelta(null, Version.parse('1.0.0')), VersionDelta.unknown);
  });
}
