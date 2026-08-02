class ReadingStat {
  final int id;
  final DateTime date;
  final int readingTimeSeconds;
  final int snippetsCreated;
  final int booksCompleted;

  ReadingStat({
    required this.id,
    required this.date,
    this.readingTimeSeconds = 0,
    this.snippetsCreated = 0,
    this.booksCompleted = 0,
  });

  ReadingStat copyWith({
    int? id,
    DateTime? date,
    int? readingTimeSeconds,
    int? snippetsCreated,
    int? booksCompleted,
  }) {
    return ReadingStat(
      id: id ?? this.id,
      date: date ?? this.date,
      readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
      snippetsCreated: snippetsCreated ?? this.snippetsCreated,
      booksCompleted: booksCompleted ?? this.booksCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().substring(0, 10),
    'reading_time_seconds': readingTimeSeconds,
    'snippets_created': snippetsCreated,
    'books_completed': booksCompleted,
  };

  factory ReadingStat.fromJson(Map<String, dynamic> json) => ReadingStat(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    readingTimeSeconds: json['reading_time_seconds'] as int? ?? 0,
    snippetsCreated: json['snippets_created'] as int? ?? 0,
    booksCompleted: json['books_completed'] as int? ?? 0,
  );
}
