import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/couple_questions.dart';
import '../models/answer.dart';
import '../models/daily_question.dart';
import '../services/couple_game_storage.dart';

class CoupleGameController extends ChangeNotifier {
  static const String waitingPartnerText = '(en attente de ta moitié...)';

  CoupleGameController({required CoupleGameStorage storage})
    : _storage = storage;

  final CoupleGameStorage _storage;

  final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');
  final Random _random = Random();

  bool isLoading = true;
  int score = 0;
  List<Answer> answers = [];

  List<DailyQuestion> get questions => CoupleQuestions.all;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    score = await _storage.loadScore();
    answers = await _storage.loadAnswers();
    answers.sort((a, b) => b.date.compareTo(a.date));

    isLoading = false;
    notifyListeners();
  }

  DailyQuestion get todayQuestion {
    final today = DateTime.now();
    final dayIndex =
        DateTime(
          today.year,
          today.month,
          today.day,
        ).difference(DateTime(2024, 1, 1)).inDays %
        questions.length;
    return questions[dayIndex];
  }

  String get todayKey => _dateKeyFormat.format(DateTime.now());

  Answer? get todayAnswer {
    for (final answer in answers) {
      final sameDate = _dateKeyFormat.format(answer.date) == todayKey;
      if (sameDate && answer.questionId == todayQuestion.id) {
        return answer;
      }
    }
    return null;
  }

  bool get hasAnsweredToday => todayAnswer != null;

  DailyQuestion? findQuestionById(int id) {
    try {
      return questions.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  String getCategoryLabel(String category) {
    switch (category) {
      case 'funny':
        return 'Drôle 😄';
      case 'deep':
        return 'Profond 💭';
      case 'challenge':
        return 'Défi 🎯';
      default:
        return category;
    }
  }

  Future<void> submitMyAnswer(String myAnswer) async {
    final sanitized = myAnswer.trim();
    if (sanitized.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final existingToday = todayAnswer;

    if (existingToday != null) {
      final updated = existingToday.copyWith(myAnswer: sanitized, date: now);
      answers = answers
          .map((item) => identical(item, existingToday) ? updated : item)
          .toList();
    } else {
      answers.insert(
        0,
        Answer(
          questionId: todayQuestion.id,
          myAnswer: sanitized,
          partnerAnswer: waitingPartnerText,
          date: now,
        ),
      );
      score += 10;
      await _storage.saveScore(score);
    }

    await _storage.saveAnswers(answers);
    notifyListeners();
  }

  String randomPromptForPartner() {
    const prompts = [
      'Ta moitié prépare sa réponse 💌',
      'Réponse partenaire bientôt 💬',
      'Encore un peu de patience 💖',
      'Suspense amoureux en cours ✨',
    ];
    return prompts[_random.nextInt(prompts.length)];
  }
}
