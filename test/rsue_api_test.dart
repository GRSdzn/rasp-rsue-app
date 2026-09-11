import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsue_rasp_app/features/schedule/data/rsue_api.dart';

class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    await release.future;
    final body = options.path.endsWith('/search/')
        ? jsonEncode([
            {'id': 1, 'name': 'ПИ-301'},
          ])
        : jsonEncode({
            'kind': 'group',
            'instance': 'ПИ-301',
            'weeks': <Object>[],
          });
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

RsueApi _apiWith(_CountingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'));
  dio.httpClientAdapter = adapter;
  return RsueApi(dio: dio);
}

void main() {
  test('deduplicates simultaneous schedule requests for one entity', () async {
    final adapter = _CountingAdapter();
    final api = _apiWith(adapter);

    final first = api.schedule('ПИ-301');
    final second = api.schedule('ПИ-301');

    expect(identical(first, second), isTrue);
    while (adapter.calls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(adapter.calls, 1);
    adapter.release.complete();
    final responses = await Future.wait([first, second]);
    expect(
      responses.every((response) => response['instance'] == 'ПИ-301'),
      isTrue,
    );
    expect(adapter.calls, 1);
  });

  test('catalogue parsing shares one search HTTP response', () async {
    final adapter = _CountingAdapter();
    final api = _apiWith(adapter);

    final items = api.searchItems();
    final groups = api.groupNames();

    while (adapter.calls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(adapter.calls, 1);
    adapter.release.complete();
    expect((await items).single['name'], 'ПИ-301');
    expect(await groups, isEmpty);
    expect(adapter.calls, 1);
  });
}
