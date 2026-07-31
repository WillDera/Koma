import 'package:isar_community/isar.dart';

part 'manga_cookie.g.dart';

@collection
@Name('MangaCookie')
class MangaCookie {
  Id? id;

  @Index(unique: true, replace: true)
  String host;

  String cookie;

  MangaCookie({
    this.id = Isar.autoIncrement,
    required this.host,
    this.cookie = '',
  });

  Map<String, dynamic> toJson() => {'id': id, 'host': host, 'cookie': cookie};

  factory MangaCookie.fromJson(Map<String, dynamic> json) => MangaCookie(
    id: json['id'] as int?,
    host: json['host'] as String,
    cookie: json['cookie'] as String? ?? '',
  );
}
