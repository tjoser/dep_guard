import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import '../core/models.dart';
import 'cache.dart';
import 'concurrency.dart';

Version? _tryParseVersion(String raw) {
  try {
    return Version.parse(raw);
  } on FormatException {
    return null;
  }
}

class PubFetchResult {
  PubFetchResult({required this.packages, required this.failed});

  final Map<String, PubPackageInfo> packages;
  final Set<String> failed;
}

abstract class PubClient {
  Future<PubFetchResult> fetchPackages(Set<String> packages);
}

class PubDevClient implements PubClient {
  PubDevClient({
    required http.Client httpClient,
    required this.cacheStore,
    required this.timeout,
    required this.retries,
    required this.userAgent,
    required this.logger,
    ConcurrencyLimiter? limiter,
  })  : _httpClient = httpClient,
        _limiter = limiter ?? ConcurrencyLimiter(8);

  final http.Client _httpClient;
  final CacheStore cacheStore;
  final Duration timeout;
  final int retries;
  final String userAgent;
  final void Function(String message) logger;
  final ConcurrencyLimiter _limiter;

  @override
  Future<PubFetchResult> fetchPackages(Set<String> packages) async {
    final results = <String, PubPackageInfo>{};
    final failed = <String>{};

    final futures = packages.map((package) async {
      final info = await _limiter.run(() => _fetchPackage(package));
      if (info == null) {
        failed.add(package);
      } else {
        results[package] = info;
      }
    }).toList();

    await Future.wait(futures);
    return PubFetchResult(packages: results, failed: failed);
  }

  Future<PubPackageInfo?> _fetchPackage(String package) async {
    final cached = cacheStore.get(package);
    if (cached != null) {
      return _parsePackageJson(package, cached.data);
    }

    final uri = Uri.parse('https://pub.dev/api/packages/$package');
    var attempt = 0;
    var delay = const Duration(milliseconds: 200);

    while (true) {
      attempt++;
      try {
        final response = await _httpClient
            .get(uri, headers: {'User-Agent': userAgent})
            .timeout(timeout);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            cacheStore.set(
              package,
              CacheEntry(fetchedAt: DateTime.now(), data: data),
            );
            return _parsePackageJson(package, data);
          }
        }
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt <= retries) {
            logger('pub.dev throttle for $package, retrying ($attempt).');
            await Future<void>.delayed(delay);
            delay *= 2;
            continue;
          }
        }
        return null;
      } on TimeoutException {
        if (attempt <= retries) {
          await Future<void>.delayed(delay);
          delay *= 2;
          continue;
        }
        return null;
      } catch (_) {
        if (attempt <= retries) {
          await Future<void>.delayed(delay);
          delay *= 2;
          continue;
        }
        return null;
      }
    }
  }

  PubPackageInfo? _parsePackageJson(String name, Map<String, dynamic> data) {
    final latestNode = data['latest'];
    Version? latestVersion;
    DateTime? latestPublished;
    if (latestNode is Map<String, dynamic>) {
      final versionRaw = latestNode['version'];
      if (versionRaw is String) {
        latestVersion = _tryParseVersion(versionRaw);
      }
      final publishedRaw = latestNode['published'];
      if (publishedRaw is String) {
        latestPublished = DateTime.tryParse(publishedRaw);
      }
    }
    final versions = <Version>[];
    final versionsNode = data['versions'];
    if (versionsNode is List) {
      for (final entry in versionsNode) {
        if (entry is Map<String, dynamic>) {
          final versionRaw = entry['version'];
          if (versionRaw is String) {
            final parsed = _tryParseVersion(versionRaw);
            if (parsed != null) {
              versions.add(parsed);
            }
          }
        }
      }
    }
    final isDiscontinued = data['isDiscontinued'] == true;
    final replacedBy = data['replacedBy'];

    return PubPackageInfo(
      name: name,
      latestVersion: latestVersion,
      latestPublished: latestPublished,
      isDiscontinued: isDiscontinued,
      replacedBy: replacedBy is String ? replacedBy : null,
      versions: versions,
    );
  }
}
