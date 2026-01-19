import 'dart:io';

import 'package:dep_guard/src/pub/cache.dart';
import 'package:test/test.dart';

void main() {
  test('cache read/write and ttl', () {
    final tempDir = Directory.systemTemp.createTempSync('dep_guard_test');
    final cache = CacheStore(
      ttl: const Duration(hours: 1),
      enabled: true,
      projectDir: tempDir,
    );

    final entry = CacheEntry(
      fetchedAt: DateTime.now(),
      data: {'latest': {'version': '1.0.0'}},
    );
    cache.set('alpha', entry);

    final cached = cache.get('alpha');
    expect(cached, isNotNull);
    expect(cached!.data['latest']['version'], '1.0.0');
  });

  test('corrupted cache does not crash', () {
    final tempDir = Directory.systemTemp.createTempSync('dep_guard_test');
    final cache = CacheStore(
      ttl: const Duration(hours: 1),
      enabled: true,
      projectDir: tempDir,
    );
    final file = cache.cacheFile;
    if (file == null) {
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('{not json');

    final entry = cache.get('missing');
    expect(entry, isNull);
  });
}
