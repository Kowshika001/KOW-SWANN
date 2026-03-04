import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/answer.dart';

class CoupleGameStorage {
  static const String _answersKey = 'couple_game_answers';
  static const String _scoreKey = 'couple_game_score';

  Future<List<Answer>> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_answersKey) ?? [];

    return raw
        .map(
          (item) => Answer.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> saveAnswers(List<Answer> answers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = answers.map((answer) => jsonEncode(answer.toJson())).toList();
    await prefs.setStringList(_answersKey, raw);
  }

  Future<int> loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scoreKey) ?? 0;
  }

  Future<void> saveScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scoreKey, value);
  }
}
