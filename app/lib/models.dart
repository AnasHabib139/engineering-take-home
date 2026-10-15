class DiaryEntry {
  const DiaryEntry({
    this.id,
    required this.recordedAt,
    required this.mood,
    this.symptoms = const [],
    this.note,
  });

  final int? id;
  final DateTime recordedAt;
  final int mood;
  final List<String> symptoms;
  final String? note;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as int,
    recordedAt: DateTime.parse(json['recorded_at'] as String),
    mood: json['mood'] as int,
    symptoms: List<String>.from(json['symptoms'] as List),
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'mood': mood,
    'symptoms': symptoms,
    'note': note,
  };
}
