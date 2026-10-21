import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/archive_api_service.dart';

void main() {
  final metadataManifest = {
    'name': 'AIOMetadata',
    'resources': ['catalog', 'meta'],
    'types': ['movie', 'series'],
    'catalogs': [
      {'type': 'movie', 'id': 'top', 'name': 'Top Movies'},
      {'type': 'series', 'id': 'shows', 'name': 'Shows'},
    ],
  };

  test('metadata-only manifests remain rejected for playback sources', () async {
    final api = ArchiveApiService(client: MockClient((_) async =>
        http.Response(jsonEncode(metadataManifest), 200)));
    await expectLater(
      api.fetchManifest('https://example.org/manifest.json'),
      throwsA(isA<ArchiveApiException>()),
    );
  });

  test('explicit metadata-only mode accepts AIOMetadata catalogs', () async {
    final api = ArchiveApiService(client: MockClient((_) async =>
        http.Response(jsonEncode(metadataManifest), 200)));
    final source = await api.fetchManifest(
      'https://example.org/manifest.json',
      allowMetadataOnly: true,
    );
    expect(source.name, 'AIOMetadata');
    expect(source.catalogs.length, 2);
    expect(source.catalogs.first.id, 'top');
  });
}
