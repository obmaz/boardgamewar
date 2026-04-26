import 'dart:io';

import '../models/boardgame_info.dart';
import '../utils/string_utils.dart';

class BggService {
  static const String _baseUrl = 'https://boardgamegeek.com/xmlapi2';
  static DateTime? _lastRequestAt;

  static Future<BoardGameInfo?> searchBoardGame(String rawQuery) async {
    final results = await searchBoardGameCandidates(rawQuery);
    if (results.isEmpty) return null;
    return results.first;
  }

  static Future<List<BoardGameInfo>> searchBoardGameCandidates(
      String rawQuery) async {
    final query = _normalizeQuery(rawQuery);
    if (query.length < 3) return [];

    final searchXml = await _getXml(
      '$_baseUrl/search?query=${Uri.encodeQueryComponent(query)}&type=boardgame',
    );
    if (searchXml == null || searchXml.isEmpty) return [];

    final candidates = _parseSearchCandidates(searchXml);
    if (candidates.isEmpty) return [];

    candidates.sortByQuery(query);
    final best = candidates.first;
    if (best.score < 0.35) return [];

    final selectedCandidates = candidates
        .where((candidate) => candidate.score >= 0.35)
        .where((candidate) => (best.score - candidate.score) <= 0.18)
        .take(3)
        .toList();

    final results = <BoardGameInfo>[];
    for (final candidate in selectedCandidates) {
      results.add(await _loadCandidateDetail(candidate, query));
    }
    return results;
  }

  static Future<BoardGameInfo> _loadCandidateDetail(
    _SearchCandidate candidate,
    String query,
  ) async {
    final detailXml = await _getXml(
      '$_baseUrl/thing?id=${candidate.id}&stats=1&marketplace=1',
    );
    if (detailXml == null || detailXml.isEmpty) {
      return BoardGameInfo(
        bggId: candidate.id,
        name: candidate.name,
        yearPublished: candidate.yearPublished,
        confidence: candidate.score,
        matchedQuery: query,
      );
    }

    return _parseBoardGameInfo(
      detailXml,
      fallbackName: candidate.name,
      fallbackYear: candidate.yearPublished,
      confidence: candidate.score,
      matchedQuery: query,
    );
  }

  static Future<String?> _getXml(String url) async {
    await _respectRateLimit();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set(HttpHeaders.userAgentHeader, 'ARBoardgameScanner/1.0');
        final response = await request.close();
        final body = await response.transform(const SystemEncoding().decoder).join();

        if (response.statusCode == 200) {
          _lastRequestAt = DateTime.now();
          return body;
        }

        if (response.statusCode == 429 ||
            response.statusCode == 500 ||
            response.statusCode == 503) {
          await Future.delayed(Duration(milliseconds: 1200 * (attempt + 1)));
          continue;
        }

        return null;
      }
    } finally {
      client.close(force: true);
    }

    return null;
  }

  static Future<void> _respectRateLimit() async {
    if (_lastRequestAt == null) return;
    final elapsed = DateTime.now().difference(_lastRequestAt!);
    if (elapsed < const Duration(milliseconds: 1200)) {
      await Future.delayed(const Duration(milliseconds: 1200) - elapsed);
    }
  }

  static List<_SearchCandidate> _parseSearchCandidates(String xml) {
    final itemPattern =
        RegExp(r'<item\b[^>]*id="(\d+)"[^>]*>([\s\S]*?)</item>', multiLine: true);
    final items = <_SearchCandidate>[];

    for (final match in itemPattern.allMatches(xml)) {
      final id = int.tryParse(match.group(1) ?? '');
      final body = match.group(2) ?? '';
      if (id == null) continue;

      final names = RegExp(
        r'<name\b[^>]*value="([^"]+)"[^>]*/?>',
        multiLine: true,
      ).allMatches(body).map((m) => m.group(1)!).toList();
      if (names.isEmpty) continue;

      final primaryName = names.first;
      final year = int.tryParse(
        _extractTagValue(body, 'yearpublished') ?? '',
      );

      items.add(
        _SearchCandidate(
          id: id,
          name: primaryName,
          yearPublished: year,
          score: 0,
        ),
      );
    }

    return items;
  }

  static BoardGameInfo _parseBoardGameInfo(
    String xml, {
    required String fallbackName,
    required int? fallbackYear,
    required double confidence,
    required String matchedQuery,
  }) {
    final name = _extractPrimaryName(xml) ?? fallbackName;
    final year = int.tryParse(_extractTagValue(xml, 'yearpublished') ?? '') ?? fallbackYear;
    final publisher = _extractLinkValue(xml, 'boardgamepublisher');
    final thumbnailUrl = _extractSimpleNode(xml, 'thumbnail');
    final averageRating = double.tryParse(_extractStatsValue(xml, 'average') ?? '');
    final bayesAverage = double.tryParse(_extractStatsValue(xml, 'bayesaverage') ?? '');
    final minPlayers = int.tryParse(_extractTagValue(xml, 'minplayers') ?? '');
    final maxPlayers = int.tryParse(_extractTagValue(xml, 'maxplayers') ?? '');
    final playingTime = int.tryParse(_extractTagValue(xml, 'playingtime') ?? '');

    int? rank;
    final rankMatch = RegExp(
      r'<rank\b[^>]*name="boardgame"[^>]*value="([^"]+)"',
      multiLine: true,
    ).firstMatch(xml);
    if (rankMatch != null && rankMatch.group(1) != 'Not Ranked') {
      rank = int.tryParse(rankMatch.group(1) ?? '');
    }

    double? minPriceUsd;
    final priceMatches = RegExp(
      r'<price\b[^>]*currency="USD"[^>]*value="([^"]+)"',
      multiLine: true,
    ).allMatches(xml);
    for (final match in priceMatches) {
      final price = double.tryParse(match.group(1) ?? '');
      if (price == null) continue;
      if (minPriceUsd == null || price < minPriceUsd) {
        minPriceUsd = price;
      }
    }

    return BoardGameInfo(
      bggId: int.tryParse(
            RegExp(r'<item\b[^>]*id="(\d+)"').firstMatch(xml)?.group(1) ?? '',
          ) ??
          0,
      name: name,
      yearPublished: year,
      publisher: publisher,
      thumbnailUrl: thumbnailUrl,
      averageRating: averageRating,
      bayesAverageRating: bayesAverage,
      rank: rank,
      minPriceUsd: minPriceUsd,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      playingTime: playingTime,
      confidence: confidence,
      matchedQuery: matchedQuery,
    );
  }

  static String _normalizeQuery(String input) {
    return input
        .replaceAll(RegExp(r'[^a-zA-Z0-9가-힣\s:&\-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .take(6)
        .join(' ')
        .trim();
  }

  static String? _extractTagValue(String xml, String tag) {
    final match = RegExp(
      '<$tag\\b[^>]*value="([^"]+)"',
      multiLine: true,
    ).firstMatch(xml);
    return match?.group(1);
  }

  static String? _extractSimpleNode(String xml, String tag) {
    final match = RegExp(
      '<$tag>([\\s\\S]*?)</$tag>',
      multiLine: true,
    ).firstMatch(xml);
    return match?.group(1)?.trim();
  }

  static String? _extractPrimaryName(String xml) {
    final match = RegExp(
      r'<name\b[^>]*type="primary"[^>]*value="([^"]+)"',
      multiLine: true,
    ).firstMatch(xml);
    return match?.group(1);
  }

  static String? _extractLinkValue(String xml, String type) {
    final match = RegExp(
      '<link\\b[^>]*type="$type"[^>]*value="([^"]+)"',
      multiLine: true,
    ).firstMatch(xml);
    return match?.group(1);
  }

  static String? _extractStatsValue(String xml, String statName) {
    final match = RegExp(
      '<$statName\\b[^>]*value="([^"]+)"',
      multiLine: true,
    ).firstMatch(xml);
    return match?.group(1);
  }
}

class _SearchCandidate {
  final int id;
  final String name;
  final int? yearPublished;
  double score;

  _SearchCandidate({
    required this.id,
    required this.name,
    required this.yearPublished,
    required this.score,
  });
}

extension on List<_SearchCandidate> {
  void sortByQuery(String query) {
    for (final candidate in this) {
      final normalizedName = BggService._normalizeQuery(candidate.name).toLowerCase();
      final normalizedQuery = BggService._normalizeQuery(query).toLowerCase();
      var score = StringUtils.similarity(normalizedQuery, normalizedName);

      final compactQuery = normalizedQuery.replaceAll(' ', '');
      final compactName = normalizedName.replaceAll(' ', '');
      final compactSimilarity = StringUtils.similarity(compactQuery, compactName);
      if (compactSimilarity > score) {
        score = compactSimilarity;
      }

      if (normalizedName.contains(normalizedQuery)) {
        score += 0.25;
      }

      if (compactName.contains(compactQuery) && compactQuery.length >= 4) {
        score += 0.18;
      }

      final queryWords = normalizedQuery.split(' ');
      final nameWords = normalizedName.split(' ');
      final overlap = queryWords.where(nameWords.contains).length;
      score += overlap * 0.08;

      final partialOverlap = queryWords.where((queryWord) {
        return nameWords.any((nameWord) =>
            nameWord.contains(queryWord) || queryWord.contains(nameWord));
      }).length;
      score += partialOverlap * 0.04;

      candidate.score = score.clamp(0.0, 1.2);
    }

    sort((a, b) => b.score.compareTo(a.score));
  }
}
