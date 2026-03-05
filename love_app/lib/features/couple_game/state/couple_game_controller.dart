import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/couple_questions.dart';
import '../models/answer.dart';
import '../models/daily_question.dart';
import '../services/couple_game_storage.dart';

class CoupleGameController extends ChangeNotifier {
  static const String waitingPartnerText = '(en attente de ta moitié...)';

  CoupleGameController.local({required CoupleGameStorage storage})
    : _storage = storage,
      _firestore = null,
      pairId = null,
      currentUid = null,
      partnerUid = null;

  CoupleGameController.online({
    required FirebaseFirestore firestore,
    required this.pairId,
    required this.currentUid,
    required this.partnerUid,
  }) : _firestore = firestore,
       _storage = null;

  final CoupleGameStorage? _storage;
  final FirebaseFirestore? _firestore;

  final String? pairId;
  final String? currentUid;
  final String? partnerUid;

  final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');
  final Random _random = Random();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pairSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _answersSub;

  bool isLoading = true;
  int score = 0;
  List<Answer> answers = [];

  bool get _isOnlineMode =>
      _firestore != null &&
      pairId != null &&
      currentUid != null &&
      partnerUid != null;

  List<DailyQuestion> get questions => CoupleQuestions.all;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    if (_isOnlineMode) {
      _attachRealtimeListeners();
    } else {
      final storage = _storage;
      if (storage == null) {
        isLoading = false;
        notifyListeners();
        return;
      }
      score = await storage.loadScore();
      answers = await storage.loadAnswers();
      answers.sort((a, b) => b.date.compareTo(a.date));
      isLoading = false;
      notifyListeners();
    }
  }

  void _attachRealtimeListeners() {
    _pairSub?.cancel();
    _answersSub?.cancel();

    final firestore = _firestore!;
    final pairRef = firestore.collection('pairs').doc(pairId);

    _pairSub = pairRef.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        score = (data['compatibilityScore'] as num?)?.toInt() ?? 0;
      }
      isLoading = false;
      notifyListeners();
    });

    _answersSub = pairRef
        .collection('daily_quiz_answers')
        .orderBy(FieldPath.documentId, descending: true)
        .snapshots()
        .listen((snapshot) {
          answers = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final date = DateTime.tryParse(doc.id) ?? DateTime.now();
                final mapAnswers =
                    (data['answers'] as Map<String, dynamic>? ?? {});
                final my = (mapAnswers[currentUid] as String?) ?? '';
                final partner =
                    (mapAnswers[partnerUid] as String?) ?? waitingPartnerText;

                return Answer(
                  questionId: (data['questionId'] as num?)?.toInt() ?? 0,
                  myAnswer: my,
                  partnerAnswer: partner,
                  date: date,
                );
              })
              .where((a) => a.questionId > 0)
              .toList();

          answers.sort((a, b) => b.date.compareTo(a.date));
          isLoading = false;
          notifyListeners();
        });
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

  bool get hasAnsweredToday {
    final answer = todayAnswer;
    if (answer == null) return false;
    return answer.myAnswer.trim().isNotEmpty;
  }

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

    if (_isOnlineMode) {
      await _submitOnlineAnswer(sanitized);
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
      final storage = _storage;
      if (storage != null) {
        await storage.saveScore(score);
      }
    }

    final storage = _storage;
    if (storage != null) {
      await storage.saveAnswers(answers);
    }
    notifyListeners();
  }

  Future<void> _submitOnlineAnswer(String sanitized) async {
    final firestore = _firestore!;
    final pairRef = firestore.collection('pairs').doc(pairId);
    final quizRef = pairRef.collection('daily_quiz_answers').doc(todayKey);

    await firestore.runTransaction((tx) async {
      final quizSnap = await tx.get(quizRef);
      final pairSnap = await tx.get(pairRef);

      final existingQuiz = quizSnap.data() ?? {};
      final existingAnswers =
          (existingQuiz['answers'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, '$value'),
          );

      existingAnswers[currentUid!] = sanitized;

      tx.set(quizRef, {
        'questionId': todayQuestion.id,
        'answers': existingAnswers,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final partnerAnswer = existingAnswers[partnerUid!];
      final alreadyScored = (existingQuiz['scored'] as bool?) ?? false;

      if (!alreadyScored &&
          partnerAnswer != null &&
          partnerAnswer.trim().isNotEmpty) {
        final pairData = pairSnap.data() ?? {};
        final currentScore =
            (pairData['compatibilityScore'] as num?)?.toInt() ?? 0;
        tx.update(pairRef, {'compatibilityScore': currentScore + 10});
        tx.set(quizRef, {'scored': true}, SetOptions(merge: true));
      }
    });
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

  @override
  void dispose() {
    _pairSub?.cancel();
    _answersSub?.cancel();
    super.dispose();
  }
}
