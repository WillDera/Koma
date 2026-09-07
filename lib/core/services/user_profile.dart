import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage.dart';

// ValueNotifier lives in foundation.dart

/// Local user profile + first-run onboarding state (no accounts).
class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.preferredGenres,
    required this.onboardingCompleted,
    this.avatarPath,
  });

  final String displayName;
  final List<String> preferredGenres;
  final bool onboardingCompleted;

  /// Local file path for profile photo, if set.
  final String? avatarPath;

  String get firstName {
    final t = displayName.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }

  /// Library header: `"Alex's Library"` or `"Library"` when unnamed.
  String get libraryTitle {
    final name = firstName.isNotEmpty ? firstName : displayName.trim();
    if (name.isEmpty) return 'Library';
    if (name.toLowerCase().endsWith('s')) return "$name' Library";
    return "$name's Library";
  }

  bool get hasAvatar {
    final path = avatarPath;
    return path != null && path.isNotEmpty && File(path).existsSync();
  }

  /// Time-of-day greeting, optionally with the user's first name.
  String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    final base = hour < 5
        ? 'Good night'
        : hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : hour < 22
        ? 'Good evening'
        : 'Good night';
    final name = firstName;
    if (name.isEmpty) return base;
    return '$base, $name';
  }

  UserProfile copyWith({
    String? displayName,
    List<String>? preferredGenres,
    bool? onboardingCompleted,
    String? Function()? avatarPath,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      avatarPath: avatarPath != null ? avatarPath() : this.avatarPath,
    );
  }
}

/// Kenji-inspired genre chips used in onboarding (stored as labels).
class OnboardingGenres {
  OnboardingGenres._();

  static const options = <({String emoji, String label})>[
    // Core
    (emoji: '💥', label: 'Action'),
    (emoji: '🗺️', label: 'Adventure'),
    (emoji: '💘', label: 'Romance'),
    (emoji: '🎭', label: 'Comedy'),
    (emoji: '🎩', label: 'Drama'),
    (emoji: '🪄', label: 'Fantasy'),
    (emoji: '🧪', label: 'Sci-Fi'),
    (emoji: '👺', label: 'Mystery'),
    (emoji: '🔪', label: 'Horror'),
    (emoji: '💪', label: 'Superhero'),
    // Manga / comic tones
    (emoji: '🏫', label: 'School'),
    (emoji: '⚔️', label: 'Martial Arts'),
    (emoji: '🌀', label: 'Psychological'),
    (emoji: '👀', label: 'Thriller'),
    (emoji: '👻', label: 'Supernatural'),
    (emoji: '🕰️', label: 'Historical'),
    (emoji: '🚀', label: 'Mecha'),
    (emoji: '🎮', label: 'Game'),
    (emoji: '🎵', label: 'Music'),
    (emoji: '🏀', label: 'Sports'),
    (emoji: '🍜', label: 'Slice of Life'),
    (emoji: '📖', label: 'Isekai'),
    (emoji: '👑', label: 'Royalty'),
    (emoji: '💼', label: 'Office'),
    (emoji: '🌙', label: 'Dark Fantasy'),
    (emoji: '🏙️', label: 'Urban Fantasy'),
    (emoji: '🧬', label: 'Cyberpunk'),
    (emoji: '🌿', label: 'Nature'),
    // Audience / format
    (emoji: '👦', label: 'Shonen'),
    (emoji: '👧', label: 'Shojo'),
    (emoji: '👨', label: 'Seinen'),
    (emoji: '👩', label: 'Josei'),
    (emoji: '📚', label: 'Literary'),
    (emoji: '🕵️', label: 'Crime'),
    (emoji: '✈️', label: 'Travel'),
    (emoji: '🧒', label: 'Kids'),
    (emoji: '💞', label: 'BL'),
    (emoji: '💗', label: 'GL'),
    (emoji: '🔞', label: 'Mature'),
    (emoji: '😂', label: 'Gag'),
    (emoji: '🧩', label: 'Puzzle'),
    (emoji: '📱', label: 'Webtoon'),
    (emoji: '📰', label: 'Manhwa'),
    (emoji: '🀄', label: 'Manhua'),
    (emoji: '📗', label: 'Light Novel'),
    (emoji: '📘', label: 'Non-Fiction'),
    (emoji: '🧚', label: 'Fairy Tale'),
    (emoji: '🌋', label: 'Apocalypse'),
    (emoji: '🧙', label: 'Magic'),
  ];

  static String? emojiFor(String label) {
    for (final opt in options) {
      if (opt.label == label) return opt.emoji;
    }
    return null;
  }
}

/// Notifies [GoRouter] when onboarding / profile gates change.
final userProfileListenable = ValueNotifier<int>(0);

class UserProfileNotifier extends Notifier<UserProfile> {
  static const prefsName = 'user_display_name';
  static const prefsGenres = 'user_preferred_genres';
  static const prefsOnboarding = 'onboarding_completed';
  static const prefsAvatar = 'user_avatar_path';

  /// Last known onboarding flag for [GoRouter] redirects (no BuildContext).
  static bool peekOnboardingCompleted = true;

  @override
  UserProfile build() {
    // Hydrated in [load] before first frame; placeholder until then.
    return const UserProfile(
      displayName: '',
      preferredGenres: [],
      onboardingCompleted: true,
    );
  }

  void _publish(UserProfile next) {
    state = next;
    peekOnboardingCompleted = next.onboardingCompleted;
    userProfileListenable.value++;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(prefsName) ?? '';
    final genres = prefs.getStringList(prefsGenres) ?? const <String>[];
    final completed = _resolveOnboardingCompleted(prefs);
    final avatar = prefs.getString(prefsAvatar);
    _publish(
      UserProfile(
        displayName: name,
        preferredGenres: List<String>.unmodifiable(genres),
        onboardingCompleted: completed,
        avatarPath: avatar != null && avatar.isNotEmpty ? avatar : null,
      ),
    );
  }

  /// Existing installs (pre-onboarding) skip the flow; fresh prefs do not.
  static bool _resolveOnboardingCompleted(SharedPreferences prefs) {
    final stored = prefs.getBool(prefsOnboarding);
    if (stored != null) return stored;
    final looksExisting =
        prefs.containsKey('theme_mode') ||
        prefs.containsKey('library_is_grid_view') ||
        prefs.containsKey('storage_root_path') ||
        prefs.containsKey('accent_index');
    return looksExisting;
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsName, trimmed);
    _publish(state.copyWith(displayName: trimmed));
  }

  Future<void> setPreferredGenres(List<String> genres) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsGenres, genres);
    _publish(
      state.copyWith(preferredGenres: List<String>.unmodifiable(genres)),
    );
  }

  /// Copy [sourcePath] into app documents and set as avatar.
  Future<void> setAvatarFromFile(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) return;
    final docs = await AppStorage.documents();
    final dir = Directory(p.join(docs.path, 'profile'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = (ext == '.png' || ext == '.webp' || ext == '.gif')
        ? ext
        : '.jpg';
    final dest = File(p.join(dir.path, 'avatar$safeExt'));
    if (await dest.exists()) await dest.delete();
    // Clear other avatar extensions so we don't leave stale files.
    for (final oldExt in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
      final old = File(p.join(dir.path, 'avatar$oldExt'));
      if (old.path != dest.path && await old.exists()) {
        await old.delete();
      }
    }
    await src.copy(dest.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsAvatar, dest.path);
    _publish(state.copyWith(avatarPath: () => dest.path));
  }

  Future<void> clearAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(prefsAvatar) ?? state.avatarPath;
    if (existing != null && existing.isNotEmpty) {
      final f = File(existing);
      if (await f.exists()) await f.delete();
    }
    await prefs.remove(prefsAvatar);
    _publish(state.copyWith(avatarPath: () => null));
  }

  Future<void> completeOnboarding({
    String? displayName,
    List<String>? genres,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (displayName != null) {
      final trimmed = displayName.trim();
      await prefs.setString(prefsName, trimmed);
    }
    if (genres != null) {
      await prefs.setStringList(prefsGenres, genres);
    }
    await prefs.setBool(prefsOnboarding, true);
    _publish(
      UserProfile(
        displayName: displayName?.trim() ?? state.displayName,
        preferredGenres: List<String>.unmodifiable(
          genres ?? state.preferredGenres,
        ),
        onboardingCompleted: true,
        avatarPath: state.avatarPath,
      ),
    );
  }

  /// Debug / settings: show onboarding again next launch.
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsOnboarding, false);
    _publish(state.copyWith(onboardingCompleted: false));
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfile>(UserProfileNotifier.new);
