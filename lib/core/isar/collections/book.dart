import 'package:isar_community/isar.dart';

part 'book.g.dart';

@collection
@Name('Book')
class Book {
  Id? id;

  String title;
  String? author;
  String? coverPath;

  /// Origin of this book: `local` (file picker), `web` (URL fetch),
  /// `manual` (user-typed note). Mirrors the existing `source` column.
  String source;

  String? sourceUrl;
  String? filePath;

  double progress;
  int currentChapterIndex;
  int totalChapters;
  double scrollPosition;

  String genre;
  String fileExtension;
  String description;

  /// Publication / first-release date from metadata enrichment (nullable).
  DateTime? releaseDate;

  DateTime? createdAt;
  DateTime? updatedAt;

  Book({
    this.id = Isar.autoIncrement,
    required this.title,
    this.author,
    this.coverPath,
    this.source = 'local',
    this.sourceUrl,
    this.filePath,
    this.progress = 0.0,
    this.currentChapterIndex = 0,
    this.totalChapters = 0,
    this.scrollPosition = 0.0,
    this.genre = '',
    this.fileExtension = '',
    this.description = '',
    this.releaseDate,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'cover_path': coverPath,
        'source': source,
        'source_url': sourceUrl,
        'file_path': filePath,
        'progress': progress,
        'current_chapter_index': currentChapterIndex,
        'total_chapters': totalChapters,
        'scroll_position': scrollPosition,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'genre': genre,
        'file_extension': fileExtension,
        'description': description,
        'release_date': releaseDate?.toIso8601String(),
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as int?,
        title: json['title'] as String,
        author: json['author'] as String?,
        coverPath: json['cover_path'] as String?,
        source: json['source'] as String? ?? 'local',
        sourceUrl: json['source_url'] as String?,
        filePath: json['file_path'] as String?,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        currentChapterIndex: json['current_chapter_index'] as int? ?? 0,
        totalChapters: json['total_chapters'] as int? ?? 0,
        scrollPosition: (json['scroll_position'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
        genre: json['genre'] as String? ?? '',
        fileExtension: json['file_extension'] as String? ?? '',
        description: json['description'] as String? ?? '',
        releaseDate: json['release_date'] != null
            ? DateTime.tryParse(json['release_date'] as String)
            : null,
      );
}
