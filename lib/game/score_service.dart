import 'package:shared_preferences/shared_preferences.dart';

class ScoreService {
  static const String _keyPrefix = 'best_score_phase_';

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
}
