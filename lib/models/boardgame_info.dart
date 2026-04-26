class BoardGameInfo {
  final int bggId;
  final String name;
  final int? yearPublished;
  final String? publisher;
  final String? thumbnailUrl;
  final double? averageRating;
  final double? bayesAverageRating;
  final int? rank;
  final double? minPriceUsd;
  final int? minPlayers;
  final int? maxPlayers;
  final int? playingTime;
  final double confidence;
  final String matchedQuery;

  const BoardGameInfo({
    required this.bggId,
    required this.name,
    required this.confidence,
    required this.matchedQuery,
    this.yearPublished,
    this.publisher,
    this.thumbnailUrl,
    this.averageRating,
    this.bayesAverageRating,
    this.rank,
    this.minPriceUsd,
    this.minPlayers,
    this.maxPlayers,
    this.playingTime,
  });
}
