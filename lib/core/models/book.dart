class Book {
  final int id;
  final String title;
  final String? author;
  final String? coverPath;
  final String source; // local | web | manual
  final String? sourceUrl;
  final String? filePath;
  final double progress;
  final int currentChapterIndex;
  final int totalChapters;
  final double scrollPosition;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String genre;
  final String fileExtension;

  Book({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    required this.source,
    this.sourceUrl,
    this.filePath,
    this.progress = 0.0,
    this.currentChapterIndex = 0,
    this.totalChapters = 0,
    this.scrollPosition = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.genre = '',
    this.fileExtension = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverPath,
    String? source,
    String? sourceUrl,
    String? filePath,
    double? progress,
    int? currentChapterIndex,
    int? totalChapters,
    double? scrollPosition,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? genre,
    String? fileExtension,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      filePath: filePath ?? this.filePath,
      progress: progress ?? this.progress,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      totalChapters: totalChapters ?? this.totalChapters,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      genre: genre ?? this.genre,
      fileExtension: fileExtension ?? this.fileExtension,
    );
  }

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
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'genre': genre,
        'file_extension': fileExtension,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as int,
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
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
        genre: json['genre'] as String? ?? '',
        fileExtension: json['file_extension'] as String? ?? '',
      );
}
