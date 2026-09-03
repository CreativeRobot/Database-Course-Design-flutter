class SecurityQuestion {
  const SecurityQuestion({required this.key, required this.question});

  factory SecurityQuestion.fromJson(dynamic json) {
    return SecurityQuestion(
      key: json['key'] as String? ?? '',
      question: json['question'] as String? ?? '',
    );
  }

  final String key;
  final String question;
}

class SecurityAnswer {
  const SecurityAnswer({required this.questionKey, required this.answer});

  Map<String, dynamic> toJson() => {
        'questionKey': questionKey,
        'answer': answer,
      };

  final String questionKey;
  final String answer;
}
