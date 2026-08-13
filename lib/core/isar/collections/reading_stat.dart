import 'package:isar_community/isar.dart';

part 'reading_stat.g.dart';

@collection
@Name('ReadingStat')
class ReadingStat {
  Id? id;

  /// Calendar day, unique. Stored as DateTime at midnight (UTC) — the
  /// existing Drift schema stores `date TEXT NOT NULL UNIQUE` as
  /// `YYYY-MM-DD`; we keep the same logical key but use Isar's native
  /// DateTime type.
  @Index(unique: true, replace: true)
  DateTime date;

  int readingTimeSeconds;
  int snippetsCreated;
  int booksCompleted;

  ReadingStat({
    this.id = Isar.autoIncrement,
    required this.date,
    this.readingTimeSeconds = 0,
    this.snippetsCreated = 0,
    this.booksCompleted = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().substring(0, 10),
    'reading_time_seconds': readingTimeSeconds,
    'snippets_created': snippetsCreated,
    'books_completed': booksCompleted,
  };

  factory ReadingStat.fromJson(Map<String, dynamic> json) => ReadingStat(
    id: json['id'] as int?,
    date: DateTime.parse(json['date'] as String),
    readingTimeSeconds: json['reading_time_seconds'] as int? ?? 0,
    snippetsCreated: json['snippets_created'] as int? ?? 0,
    booksCompleted: json['books_completed'] as int? ?? 0,
  );
}
