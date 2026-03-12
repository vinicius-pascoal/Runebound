import 'package:shared_preferences/shared_preferences.dart';

class ScoreService {
  static const String _keyPrefix = 'best_score_phase_';
  static const String _infiniteKeyPrefix = 'best_score_infinite_';

  // ── Fases de campanha ────────────────────────────────────────────────────

  static Future<int> getBestScore(int phaseId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyPrefix$phaseId') ?? 0;
  }

  static Future<void> saveBestScore(int phaseId, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBestScore(phaseId);
    if (score > current) {
      await prefs.setInt('$_keyPrefix$phaseId', score);
    }
  }

  static Future<Map<int, int>> getAllBestScores(int phaseCount) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <int, int>{};
    for (int i = 1; i <= phaseCount; i++) {
      result[i] = prefs.getInt('$_keyPrefix$i') ?? 0;
    }
    return result;
  }

  // ── Modos infinitos ──────────────────────────────────────────────────────

  static Future<int> getInfiniteBestScore(int modeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_infiniteKeyPrefix$modeId') ?? 0;
  }

  static Future<void> saveInfiniteBestScore(int modeId, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getInfiniteBestScore(modeId);
    if (score > current) {
      await prefs.setInt('$_infiniteKeyPrefix$modeId', score);
    }
  }

  static Future<List<int>> getAllInfiniteBestScores(int modeCount) async {
    final prefs = await SharedPreferences.getInstance();
    return List.generate(
      modeCount,
      (i) => prefs.getInt('$_infiniteKeyPrefix$i') ?? 0,
    );
  }
}
