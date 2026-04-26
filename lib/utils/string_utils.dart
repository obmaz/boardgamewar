import 'dart:math';

class StringUtils {
  /// 두 문자열 사이의 레벤슈타인 거리(Levenshtein Distance)를 계산합니다.
  static int levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  /// 0.0 ~ 1.0 사이의 유사도 점수를 반환합니다. (1.0일수록 일치)
  static double similarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    int dist = levenshtein(s1, s2);
    int maxLen = max(s1.length, s2.length);
    return 1.0 - (dist / maxLen);
  }
}
