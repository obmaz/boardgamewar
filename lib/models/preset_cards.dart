import '../services/card_database.dart';

export '../services/card_database.dart' show CardEntry;

class PresetCard {
  final CardEntry entry;

  const PresetCard({required this.entry});

  static PresetCard fromEntry(CardEntry entry) => PresetCard(entry: entry);

  String get id => entry.id;
  String get imagePath => entry.imagePath;
  String get imageType => entry.type;
  String get name => entry.displayName;
  int get hp => entry.hp;
  int get def => entry.def;
  String get attackRangeLabel => entry.attackRangeLabel;
  String? get geekRating => entry.geekRating;
  String? get avgRating => entry.avgRating;
}

List<PresetCard> kPresetCards = [];
