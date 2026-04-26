import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/card_model.dart';

class BattleDefaults {
  final int hp;
  final int atkMin;
  final int atkMax;
  final int def;

  const BattleDefaults({
    required this.hp,
    required this.atkMin,
    required this.atkMax,
    required this.def,
  });

  factory BattleDefaults.fromJson(Map<String, dynamic> json) {
    return BattleDefaults(
      hp: json['hp'] as int,
      atkMin: json['atkMin'] as int,
      atkMax: json['atkMax'] as int,
      def: json['def'] as int,
    );
  }
}

/// boardgames.json 에서 로드한 보드게임 원본 데이터
class CardEntry {
  final String id;
  final String name;
  final String type;
  final String imagePath;
  final String? nameKo;
  final String? thumbnailUrl;
  final int hp;
  final int def;
  final int atkMin;
  final int atkMax;
  final List<CardSkill> skills;
  final String? geekRating;
  final String? avgRating;

  const CardEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.imagePath,
    this.nameKo,
    this.thumbnailUrl,
    required this.hp,
    required this.def,
    required this.atkMin,
    required this.atkMax,
    this.skills = const [],
    this.geekRating,
    this.avgRating,
  });

  factory CardEntry.fromJson(
    Map<String, dynamic> json,
    BattleDefaults defaults,
  ) {
    return CardEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      type: (json['type'] as String?) ?? 'boardgame',
      imagePath: (json['thumbnailUrl'] as String?) ??
          (json['imagePath'] as String?) ??
          'assets/images/title_background.jpg',
      nameKo: json['name_ko'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      hp: (json['hp'] as int?) ?? defaults.hp,
      def: (json['def'] as int?) ?? defaults.def,
      atkMin: (json['atkMin'] as int?) ?? defaults.atkMin,
      atkMax: (json['atkMax'] as int?) ?? defaults.atkMax,
      geekRating: json['geekRating'] as String?,
      avgRating: json['avgRating'] as String?,
    );
  }

  UnitCard toUnitCard({Random? random}) {
    final resolvedRandom = random ?? Random();
    final safeMin = min(atkMin, atkMax);
    final safeMax = max(atkMin, atkMax);
    final attack = safeMin + resolvedRandom.nextInt(safeMax - safeMin + 1);

    return UnitCard(
      name: displayName,
      hp: hp,
      atk: attack,
      def: def,
      skills: skills,
      imagePath: imagePath,
    );
  }

  String get displayName => nameKo ?? name;

  String get attackRangeLabel => '$atkMin-$atkMax';
}

/// 보드게임 데이터베이스 — assets/boardgame_data/boardgames.json 에서 로드
class CardDatabase {
  static const String _assetPath = 'assets/boardgame_data/boardgames.json';

  static List<CardEntry>? _cache;
  static BattleDefaults? _defaultsCache;

  static Future<List<CardEntry>> load() async {
    if (_cache != null) return _cache!;

    final data = await _loadData();
    final defaults = _parseDefaults(data);
    _defaultsCache = defaults;
    _cache = (data['boardgames'] as List<dynamic>)
        .map((e) => CardEntry.fromJson(e as Map<String, dynamic>, defaults))
        .toList();
    return _cache!;
  }

  static Future<CardEntry?> findById(String id) async {
    final cards = await load();
    try {
      return cards.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<BattleDefaults> loadDefaults() async {
    if (_defaultsCache != null) return _defaultsCache!;
    final data = await _loadData();
    _defaultsCache = _parseDefaults(data);
    return _defaultsCache!;
  }

  static CardEntry createGeneratedEntry({
    required String id,
    required String name,
    String type = 'generated',
    String imagePath = 'assets/images/title_background.jpg',
    String? nameKo,
    String? thumbnailUrl,
  }) {
    final defaults = _defaultsCache ??
        const BattleDefaults(hp: 100, atkMin: 10, atkMax: 20, def: 0);

    return CardEntry(
      id: id,
      name: name,
      type: type,
      imagePath: imagePath,
      nameKo: nameKo,
      thumbnailUrl: thumbnailUrl,
      hp: defaults.hp,
      def: defaults.def,
      atkMin: defaults.atkMin,
      atkMax: defaults.atkMax,
      geekRating: null,
      avgRating: null,
    );
  }

  static void clearCache() {
    _cache = null;
    _defaultsCache = null;
  }

  static Future<Map<String, dynamic>> _loadData() async {
    final jsonStr = await rootBundle.loadString(_assetPath);
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  static BattleDefaults _parseDefaults(Map<String, dynamic> data) {
    return BattleDefaults.fromJson(
      data['battleDefaults'] as Map<String, dynamic>,
    );
  }
}
