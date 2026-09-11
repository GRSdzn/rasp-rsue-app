import 'dart:convert';
import 'dart:io';

import 'package:rsue_rasp_app/features/schedule/data/rsue_api.dart';

Future<void> main() async {
  final items = await RsueApi().searchItems();
  if (items.isEmpty ||
      items.any((item) => item['id'] is! num || item['name'] is! String)) {
    throw const FormatException('Invalid or empty catalogue response');
  }
  await File('api-search-list.json').writeAsString(jsonEncode(items));
  stdout.writeln('Saved ${items.length} catalogue entries.');
}
