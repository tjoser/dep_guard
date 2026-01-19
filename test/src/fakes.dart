import 'package:dep_guard/src/core/models.dart';
import 'package:dep_guard/src/pub/pub_client.dart';

class FakePubClient implements PubClient {
  FakePubClient({
    required this.packages,
    this.failed = const <String>{},
  });

  final Map<String, PubPackageInfo> packages;
  final Set<String> failed;

  @override
  Future<PubFetchResult> fetchPackages(Set<String> packages) async {
    return PubFetchResult(packages: this.packages, failed: failed);
  }
}

class ThrowingPubClient implements PubClient {
  @override
  Future<PubFetchResult> fetchPackages(Set<String> packages) async {
    throw Exception('Network failure');
  }
}
