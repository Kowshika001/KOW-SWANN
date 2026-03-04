class Answer {
  final int questionId;
  final String myAnswer;
  final String partnerAnswer;
  final DateTime date;

  const Answer({
    required this.questionId,
    required this.myAnswer,
    required this.partnerAnswer,
    required this.date,
  });

  Answer copyWith({
    int? questionId,
    String? myAnswer,
    String? partnerAnswer,
    DateTime? date,
  }) {
    return Answer(
      questionId: questionId ?? this.questionId,
      myAnswer: myAnswer ?? this.myAnswer,
      partnerAnswer: partnerAnswer ?? this.partnerAnswer,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'myAnswer': myAnswer,
      'partnerAnswer': partnerAnswer,
      'date': date.toIso8601String(),
    };
  }

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      questionId: json['questionId'] as int,
      myAnswer: json['myAnswer'] as String,
      partnerAnswer: json['partnerAnswer'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
