import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class RsueApi {
  RsueApi({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;
  Future<List<dynamic>>? _searchRequest;
  final Map<String, Future<Map<String, dynamic>>> _scheduleRequests = {};

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://rasp-api.rsue.ru/api/v1/',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (certificate, host, port) {
          if (host != 'rasp-api.rsue.ru' || port != 443) return false;
          return sha256.convert(certificate.der).toString() ==
              '7a0b038b5942365ce35adb6acfaa2ea7472bf30f4af08f207395a8464171dc36';
        };
        return client;
      },
    );
    return dio;
  }

  Future<List<Map<String, dynamic>>> searchItems() async {
    final payload = await _searchPayload();
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Set<String>> groupNames() async {
    final payload = await _searchPayload();
    final names = <String>{};
    void visit(dynamic value, {bool groupContext = false}) {
      if (value is List) {
        for (final item in value) {
          visit(item, groupContext: groupContext);
        }
      } else if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final nestedGroupContext =
            groupContext ||
            map.keys.any((key) => key.toLowerCase().contains('group'));
        if (nestedGroupContext && map['name'] is String && map['id'] is num) {
          names.add((map['name'] as String).trim());
        }
        for (final entry in map.entries) {
          visit(
            entry.value,
            groupContext:
                nestedGroupContext || entry.key.toLowerCase().contains('group'),
          );
        }
      }
    }

    visit(payload);
    return names;
  }

  Future<Map<String, dynamic>> schedule(String entityName) {
    final active = _scheduleRequests[entityName];
    if (active != null) return active;

    late final Future<Map<String, dynamic>> request;
    request = _dio
        .get<Map<String, dynamic>>(
          'schedule/lessons/${Uri.encodeComponent(entityName)}/',
        )
        .then((response) => response.data ?? const <String, dynamic>{})
        .whenComplete(() {
          if (identical(_scheduleRequests[entityName], request)) {
            _scheduleRequests.remove(entityName);
          }
        });
    _scheduleRequests[entityName] = request;
    return request;
  }

  Future<List<dynamic>> _searchPayload() {
    final active = _searchRequest;
    if (active != null) return active;

    late final Future<List<dynamic>> request;
    request = _dio
        .get<List<dynamic>>('schedule/search/')
        .then((response) => response.data ?? const <dynamic>[])
        .whenComplete(() {
          if (identical(_searchRequest, request)) _searchRequest = null;
        });
    _searchRequest = request;
    return request;
  }
}
