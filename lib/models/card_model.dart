/// 카드 단일 기술(스킬) 정보
class CardSkill {
  final String name;
  final int damage;

  const CardSkill({required this.name, required this.damage});

  factory CardSkill.fromJson(Map<String, dynamic> json) {
    return CardSkill(
      name: json['name'] as String,
      damage: json['damage'] as int,
    );
  }
}

/// 전투에 사용되는 런타임 카드 상태
class UnitCard {
  String name;
  int hp;
  int maxHp;
  int atk; // 전투용 공격력 (스킬 중 최대 데미지 기준)
  int def;
  List<CardSkill> skills;
  String? imagePath;
  String? imageUrl;
  bool isDead;

  UnitCard({
    required this.name,
    required this.hp,
    required this.atk,
    required this.def,
    this.skills = const [],
    this.imagePath,
    this.imageUrl,
  })  : maxHp = hp,
        isDead = false;

  void takeDamage(int damage) {
    hp -= damage;
    if (hp <= 0) {
      hp = 0;
      isDead = true;
    }
  }

  UnitCard clone() {
    return UnitCard(
      name: name,
      hp: maxHp,
      atk: atk,
      def: def,
      skills: skills,
      imagePath: imagePath,
      imageUrl: imageUrl,
    );
  }
}
