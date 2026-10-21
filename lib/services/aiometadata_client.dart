import 'dart:convert';
import 'package:http/http.dart' as http;

/// Stremio-compatible AIOMetadata catalog and metadata client.
///
/// The supplied manifest URL may contain a private configuration token.
/// Never log it or include it in user-facing error messages.
class AioMetadataClient {
  AioMetadataClient(this.manifestUrl, {http.Client? client})
      : _client = client ?? http.Client();

  final Uri manifestUrl;
  final http.Client _client;
  Map<String, dynamic>? _manifest;

  void dispose() => _client.close();

  Uri _resource(List<String> parts, [Map<String, String> extras = const {}]) {
    final base = manifestUrl.pathSegments.toList();
    if (base.isNotEmpty && base.last == 'manifest.json') base.removeLast();
    final segments = [...base.where((s) => s.isNotEmpty), ...parts];
    if (extras.isNotEmpty) {
      segments.add(extras.entries.map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&'));
    }
    return manifestUrl.replace(pathSegments: segments);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const FormatException('Unsupported metadata URL scheme');
    }
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Metadata provider returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid metadata response');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> loadManifest({bool refresh = false}) async {
    if (!refresh && _manifest != null) return _manifest!;
    final manifest = await _get(manifestUrl);
    if (manifest['catalogs'] is! List) {
      throw const FormatException('Manifest has no catalog list');
    }
    _manifest = manifest;
    return manifest;
  }

  Future<List<Map<String, dynamic>>> catalogs() async {
    final manifest = await loadManifest();
    return (manifest['catalogs'] as List)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> catalogItems({
    required String type,
    required String id,
    int? skip,
    String? genre,
    String? search,
  }) async {
    final catalog = (await catalogs()).where(
      (c) => c['type'] == type && c['id'] == id,
    );
    if (catalog.isEmpty) throw ArgumentError('Catalog not declared by manifest');
    final declared = (catalog.first['extra'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e['name'])
        .toSet();
    final extra = <String, String>{};
    if (skip != null && declared.contains('skip')) extra['skip'] = '$skip';
    if (genre != null && declared.contains('genre')) extra['genre'] = genre;
    if (search != null) {
      if (!declared.contains('search')) {
        throw ArgumentError('Catalog does not support search');
      }
      extra['search'] = search;
    }
    final response = await _get(_resource(['catalog', type, '$id.json'], extra));
    return (response['metas'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> metadata({
    required String type,
    required String id,
  }) async {
    final manifest = await loadManifest();
    final resources = manifest['resources'] as List? ?? const [];
    final supportsMeta = resources.any((resource) {
      if (resource == 'meta') return true;
      if (resource is! Map || resource['name'] != 'meta') return false;
      final types = resource['types'];
      return types == null || (types is List && types.contains(type));
    });
    if (!supportsMeta) return null;
    final response = await _get(_resource(['meta', type, '$id.json']));
    return response['meta'] is Map<String, dynamic>
        ? response['meta'] as Map<String, dynamic>
        : null;
  }
}
