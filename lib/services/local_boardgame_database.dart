import 'dart:convert';

import 'package:flutter/services.dart';

import '../utils/string_utils.dart';

class LocalBoardGameEntry {
  final String id;
  final String name;
  final String? nameKo;

  const LocalBoardGameEntry({
    required this.id,
    required this.name,
    this.nameKo,
  });

  factory LocalBoardGameEntry.fromJson(Map<String, dynamic> json) {
    return LocalBoardGameEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      nameKo: json['name_ko'] as String?,
    );
  }
}

class LocalBoardGameMatch {
  final LocalBoardGameEntry entry;
  final double score;
  final String matchedAlias;

  const LocalBoardGameMatch({
    required this.entry,
    required this.score,
    required this.matchedAlias,
  });
}

class LocalBoardGameDatabase {
  static const String _assetPath = 'assets/boardgame_data/boardgames.json';
  static List<LocalBoardGameEntry>? _cache;

  static Future<List<LocalBoardGameEntry>> load() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString(_assetPath);
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    _cache = (data['boardgames'] as List<dynamic>)
        .map((e) => LocalBoardGameEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  static Future<LocalBoardGameMatch?> findBestMatch(String query) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.length < 3) return null;

    final entries = await load();
    LocalBoardGameMatch? bestMatch;

    for (final entry in entries) {
      // nameKo 검색
      if (entry.nameKo != null) {
        final normalizedAlias = _normalize(entry.nameKo!);
        if (normalizedAlias.isEmpty) continue;

        var score = StringUtils.similarity(normalizedQuery, normalizedAlias);
        if (normalizedAlias.contains(normalizedQuery)) {
          score += 0.22;
        }
        if (normalizedQuery.contains(normalizedAlias) &&
            normalizedAlias.length >= 4) {
          score += 0.18;
        }

        if (bestMatch == null || score > bestMatch.score) {
          bestMatch = LocalBoardGameMatch(
            entry: entry,
            score: score,
            matchedAlias: entry.nameKo!,
          );
        }
      }

      // name 검색
      final normalizedName = _normalize(entry.name);
      if (normalizedName.isNotEmpty) {
        var score = StringUtils.similarity(normalizedQuery, normalizedName);
        if (normalizedName.contains(normalizedQuery)) {
          score += 0.22;
        }
        if (normalizedQuery.contains(normalizedName) &&
            normalizedName.length >= 4) {
          score += 0.18;
        }

        if (bestMatch == null || score > bestMatch.score) {
          bestMatch = LocalBoardGameMatch(
            entry: entry,
            score: score,
            matchedAlias: entry.name,
          );
        }
      }
    }

    if (bestMatch == null || bestMatch.score < 0.45) return null;
    return bestMatch;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9가-힣\s:&-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
  }
}
