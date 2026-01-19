import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class CacheEntry {
  CacheEntry({required this.fetchedAt, required this.data});

  final DateTime fetchedAt;
  final Map<String, dynamic> data;
}

class CacheStore {
  CacheStore({
    required this.ttl,
    required this.enabled,
    required this.projectDir,
  }) {
    cacheFile = resolveCacheFile(projectDir);
  }

  final Duration ttl;
  final bool enabled;
  final Directory projectDir;
  late final File? cacheFile;
  final Map<String, CacheEntry> _memory = {};
  Map<String, CacheEntry>? _persistent;

  bool _isFresh(CacheEntry entry) {
    return DateTime.now().difference(entry.fetchedAt) <= ttl;
  }

  CacheEntry? get(String package) {
    final memory = _memory[package];
    if (memory != null && _isFresh(memory)) {
      return memory;
    }
    if (!enabled) {
      return null;
    }
    final persistent = _loadPersistent();
    final entry = persistent[package];
    if (entry != null && _isFresh(entry)) {
      _memory[package] = entry;
      return entry;
    }
    return null;
  }

  void set(String package, CacheEntry entry) {
    _memory[package] = entry;
    if (!enabled || cacheFile == null) {
      return;
    }
    final persistent = _loadPersistent();
    persistent[package] = entry;
    _writePersistent(persistent);
  }

  Map<String, CacheEntry> _loadPersistent() {
    if (_persistent != null) {
      return _persistent!;
    }
    if (cacheFile == null) {
      _persistent = {};
      return _persistent!;
    }
    try {
      if (!cacheFile!.existsSync()) {
        _persistent = {};
        return _persistent!;
      }
      final content = cacheFile!.readAsStringSync();
      final jsonData = jsonDecode(content);
      if (jsonData is! Map<String, dynamic>) {
        _persistent = {};
        return _persistent!;
      }
      final packages = jsonData['packages'];
      final entries = <String, CacheEntry>{};
      if (packages is Map<String, dynamic>) {
        packages.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final fetchedAtRaw = value['fetchedAt'];
            final dataRaw = value['data'];
            if (fetchedAtRaw is String && dataRaw is Map<String, dynamic>) {
              final fetchedAt = DateTime.tryParse(fetchedAtRaw);
              if (fetchedAt != null) {
                entries[key] = CacheEntry(fetchedAt: fetchedAt, data: dataRaw);
              }
            }
          }
        });
      }
      _persistent = entries;
    } catch (_) {
      _persistent = {};
    }
    return _persistent!;
  }

  void _writePersistent(Map<String, CacheEntry> entries) {
    if (cacheFile == null) {
      return;
    }
    try {
      cacheFile!.parent.createSync(recursive: true);
      final jsonData = <String, dynamic>{
        'packages': entries.map((key, value) {
          return MapEntry(
            key,
            {
              'fetchedAt': value.fetchedAt.toIso8601String(),
              'data': value.data,
            },
          );
        }),
      };
      cacheFile!.writeAsStringSync(jsonEncode(jsonData));
    } catch (_) {
      // Ignore cache write failures.
    }
  }
}

File? resolveCacheFile(Directory projectDir) {
  final env = Platform.environment;
  String? baseDir;
  if (env.containsKey('XDG_CACHE_HOME')) {
    baseDir = env['XDG_CACHE_HOME'];
  } else if (Platform.isLinux || Platform.isMacOS) {
    final home = env['HOME'];
    if (home != null) {
      baseDir = p.join(home, '.cache');
    }
  } else if (Platform.isWindows) {
    final localApp = env['LOCALAPPDATA'];
    if (localApp != null) {
      baseDir = localApp;
    }
  }
  if (baseDir != null) {
    return File(p.join(baseDir, 'dep_guard', 'cache.json'));
  }
  return File(p.join(projectDir.path, '.dart_tool', 'dep_guard', 'cache.json'));
}
