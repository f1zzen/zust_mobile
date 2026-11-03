import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Новости, спонсоры и сообщество - из того же гиста, что и у версии для ПК.
const _gist = 'https://gist.githubusercontent.com/f1zzen/92a5742eb95e6e1922b268e9dd586f45/raw/';

class Person {
  final String name, note;
  const Person(this.name, this.note);
}

class Info extends ChangeNotifier {
  String newsTitle = '', newsBody = '';
  List<Person> sponsors = const [Person('neton4ik', '400₽'), Person('Рустам', '1063₽')];
  List<Person> community = const [
    Person('neton4ik', 'Первый донат на бусти'),
    Person('Анархист', 'Первый обзор на Z.UST'),
    Person('радостева', 'Z.UST-тян'),
    Person('ks', 'Z.UST-тян'),
    Person('Исчадие', 'Z.UST-тян'),
    Person('П.Ф', 'Z.UST-тян'),
    Person('T0ko', 'Z.UST-тян'),
  ];

  String get newsId => newsTitle.isEmpty ? '' : '$newsTitle\n$newsBody';

  Future<String?> _get(String file) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('$_gist$file'));
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return await res.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> load() async {
    final results = await Future.wait([_get('warning'), _get('community.json')]);
    final news = results[0]?.trim() ?? '';
    if (news.isNotEmpty && news != '#') {
      final i = news.indexOf('\n');
      newsTitle = (i < 0 ? news : news.substring(0, i)).replaceFirst(RegExp(r'^#+'), '').trim();
      newsBody = i < 0 ? '' : _plain(news.substring(i + 1).trim());
    }
    try {
      final j = jsonDecode(results[1] ?? '') as Map<String, dynamic>;
      List<Person> list(String k) => [
            for (final p in (j[k] as List? ?? const []))
              Person('${(p as Map)['name'] ?? ''}', '${p['note'] ?? ''}'),
          ];
      if (j['sponsors'] != null) sponsors = list('sponsors');
      if (j['community'] != null) community = list('community');
    } catch (_) {}
    notifyListeners();
  }

  /// Markdown → обычный текст: без **, `, # и со ссылками "текст (адрес)".
  static String _plain(String s) => s
      .split('\n')
      .map((l) {
        l = l.replaceFirst(RegExp(r'^#+\s*'), '').replaceFirst(RegExp(r'^[-*] '), '• ');
        l = l.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
        return l.replaceAllMapped(RegExp(r'\[([^\]]*)\]\(([^)]*)\)'), (m) => '${m[1]} (${m[2]})');
      })
      .join('\n')
      .trim();
}
