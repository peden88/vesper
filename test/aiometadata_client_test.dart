import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nox_iptv/services/aiometadata_client.dart';

void main() {
  test('discovers catalogs and retrieves title metadata', () async {
    final requested = <String>[];
    final httpClient = MockClient((request) async {
      requested.add(request.url.toString());
      if (request.url.path.endsWith('/manifest.json')) {
        return http.Response(jsonEncode({
          'catalogs': [
            {'type': 'movie', 'id': 'popular', 'name': 'Popular', 'extra': [{'name': 'skip'}]},
            {'type': 'series', 'id': 'search', 'name': 'Search', 'extra': [{'name': 'search'}]}
          ],
          'resources': ['catalog', 'meta']
        }), 200);
      }
      if (request.url.path.contains('/catalog/')) {
        return http.Response(jsonEncode({'metas': [{'id': 'tt123', 'name': 'Example'}]}), 200);
      }
      return http.Response(jsonEncode({'meta': {'id': 'tt123', 'name': 'Example', 'videos': []}}), 200);
    });
    final client = AioMetadataClient(
      Uri.parse('https://example.org/private-token/manifest.json'),
      client: httpClient,
    );
    expect((await client.catalogs()).length, 2);
    expect((await client.catalogItems(type: 'movie', id: 'popular', skip: 20)).single['id'], 'tt123');
    expect((await client.metadata(type: 'movie', id: 'tt123'))?['name'], 'Example');
    expect(requested.any((u) => u.contains('/private-token/catalog/movie/popular/skip=20.json')), isTrue);
    expect(requested.any((u) => u.contains('/private-token/meta/movie/tt123.json')), isTrue);
    client.dispose();
  });

  test('encodes search as a Stremio extra path segment', () async {
    final requested = <Uri>[];
    final client = AioMetadataClient(
      Uri.parse('https://example.org/token/manifest.json'),
      client: MockClient((request) async {
        requested.add(request.url);
        if (request.url.path.endsWith('/manifest.json')) {
          return http.Response(jsonEncode({
            'catalogs': [
              {'type': 'movie', 'id': 'find', 'extra': [{'name': 'search'}]}
            ],
          }), 200);
        }
        return http.Response(jsonEncode({'metas': []}), 200);
      }),
    );
    await client.catalogItems(type: 'movie', id: 'find', search: 'A & B');
    expect(requested.last.path, '/token/catalog/movie/find/search=A & B.json');
    expect(requested.last.toString(), contains('search=A%20%26%20B.json'));
    client.dispose();
  });

  test('rejects search for a catalog that does not declare it', () async {
    final client = AioMetadataClient(
      Uri.parse('https://example.org/manifest.json'),
      client: MockClient((_) async => http.Response(
        jsonEncode({'catalogs': [{'type': 'movie', 'id': 'popular'}], 'resources': ['meta']}),
        200,
      )),
    );
    await expectLater(
      client.catalogItems(type: 'movie', id: 'popular', search: 'test'),
      throwsArgumentError,
    );
    client.dispose();
  });
}
