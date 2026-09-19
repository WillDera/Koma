import 'package:flutter/material.dart';

/// Material-only icon descriptor used across the design system.
///
/// Call-sites pass an [AppIconData]; [AppIcon] renders it. Hugeicons was
/// removed to shrink the APK — every glyph maps to a built-in Material icon.
sealed class AppIconData {
  const AppIconData();

  /// Renders this icon at [size] with [color].
  Widget render({double? size, Color? color, Key? key});
}

/// A Material icon backed by [IconData].
class MaterialIconData extends AppIconData {
  final IconData icon;

  const MaterialIconData(this.icon);

  @override
  Widget render({double? size, Color? color, Key? key}) {
    return Icon(icon, key: key, size: size, color: color);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaterialIconData && other.icon == icon);

  @override
  int get hashCode => icon.hashCode;
}

/// Renders any [AppIconData]. Single entry point for icon rendering.
class AppIcon extends StatelessWidget {
  final AppIconData data;
  final double? size;
  final Color? color;

  const AppIcon({super.key, required this.data, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    return data.render(size: size, color: color);
  }
}

/// Canonical Material icon mappings. Screens should reference these rather
/// than raw [Icons] constants where a shared meaning already exists.
class AppIcons {
  AppIcons._();

  // ── Navigation ──
  static const AppIconData library = MaterialIconData(Icons.menu_book_outlined);
  static const AppIconData libraryActive = MaterialIconData(Icons.menu_book);
  static const AppIconData history = MaterialIconData(Icons.history);
  static const AppIconData historyActive = MaterialIconData(Icons.history);
  static const AppIconData snippets = MaterialIconData(
    Icons.bookmark_border_outlined,
  );
  static const AppIconData snippetsActive = MaterialIconData(Icons.bookmark);
  static const AppIconData discover = MaterialIconData(Icons.explore_outlined);
  static const AppIconData discoverActive = MaterialIconData(Icons.explore);
  static const AppIconData updates = MaterialIconData(
    Icons.notifications_outlined,
  );
  static const AppIconData updatesActive = MaterialIconData(
    Icons.notifications,
  );
  static const AppIconData search = MaterialIconData(Icons.search);
  static const AppIconData searchActive = MaterialIconData(Icons.search);
  static const AppIconData settings = MaterialIconData(Icons.settings_outlined);
  static const AppIconData settingsActive = MaterialIconData(Icons.settings);

  // ── Actions ──
  static const AppIconData add = MaterialIconData(Icons.add);
  static const AppIconData addCircle = MaterialIconData(
    Icons.add_circle_outline,
  );
  static const AppIconData back = MaterialIconData(Icons.arrow_back);
  static const AppIconData forward = MaterialIconData(Icons.arrow_forward);
  static const AppIconData close = MaterialIconData(Icons.close);
  static const AppIconData moreHorizontal = MaterialIconData(Icons.more_horiz);
  static const AppIconData moreVertical = MaterialIconData(Icons.more_vert);
  static const AppIconData share = MaterialIconData(Icons.share_outlined);
  static const AppIconData play = MaterialIconData(Icons.play_arrow);
  static const AppIconData playCircle = MaterialIconData(
    Icons.play_circle_outline,
  );
  static const AppIconData refresh = MaterialIconData(Icons.refresh);
  static const AppIconData reload = MaterialIconData(Icons.sync);
  static const AppIconData download = MaterialIconData(Icons.download_outlined);
  static const AppIconData upload = MaterialIconData(Icons.upload_outlined);
  static const AppIconData delete = MaterialIconData(Icons.delete_outline);
  static const AppIconData edit = MaterialIconData(Icons.edit_outlined);
  static const AppIconData filter = MaterialIconData(Icons.filter_list);
  static const AppIconData tune = MaterialIconData(Icons.tune);
  static const AppIconData sort = MaterialIconData(Icons.sort);
  static const AppIconData grid = MaterialIconData(Icons.grid_view);
  static const AppIconData list = MaterialIconData(Icons.view_list);
  static const AppIconData menu = MaterialIconData(Icons.menu);
  static const AppIconData check = MaterialIconData(Icons.check_circle_outline);
  static const AppIconData expand = MaterialIconData(Icons.open_in_full);
  static const AppIconData next = MaterialIconData(Icons.skip_next);
  static const AppIconData previous = MaterialIconData(Icons.skip_previous);

  // ── Content / status ──
  static const AppIconData book = MaterialIconData(Icons.book_outlined);
  static const AppIconData bookOpen = MaterialIconData(
    Icons.menu_book_outlined,
  );
  static const AppIconData bookmark = MaterialIconData(Icons.bookmark);
  static const AppIconData bookmarkAdd = MaterialIconData(
    Icons.bookmark_add_outlined,
  );
  static const AppIconData star = MaterialIconData(Icons.star_outline);
  static const AppIconData starHalf = MaterialIconData(Icons.star_half);
  static const AppIconData lock = MaterialIconData(Icons.lock_outline);
  static const AppIconData clock = MaterialIconData(Icons.schedule);
  static const AppIconData calendar = MaterialIconData(
    Icons.calendar_today_outlined,
  );
  static const AppIconData schedule = MaterialIconData(Icons.access_time);
  static const AppIconData person = MaterialIconData(Icons.person_outline);
  static const AppIconData globe = MaterialIconData(Icons.public);
  static const AppIconData translate = MaterialIconData(Icons.translate);
  static const AppIconData note = MaterialIconData(
    Icons.sticky_note_2_outlined,
  );
  static const AppIconData alert = MaterialIconData(Icons.error_outline);
  static const AppIconData info = MaterialIconData(Icons.info_outline);
  static const AppIconData hourglass = MaterialIconData(Icons.hourglass_empty);
  static const AppIconData loading = MaterialIconData(Icons.autorenew);
  static const AppIconData cloudLoading = MaterialIconData(
    Icons.cloud_sync_outlined,
  );

  // ── Reader ──
  static const AppIconData textToSpeech = MaterialIconData(
    Icons.record_voice_over_outlined,
  );
  static const AppIconData volumeHigh = MaterialIconData(Icons.volume_up);
  static const AppIconData volumeLow = MaterialIconData(Icons.volume_down);
  static const AppIconData fullscreen = MaterialIconData(Icons.fullscreen);
  static const AppIconData fullscreenExit = MaterialIconData(
    Icons.fullscreen_exit,
  );
  static const AppIconData chapterList = MaterialIconData(Icons.list);
  static const AppIconData brightness = MaterialIconData(
    Icons.wb_sunny_outlined,
  );
  static const AppIconData fontSize = MaterialIconData(Icons.text_fields);
  static const AppIconData textAlignLeft = MaterialIconData(
    Icons.format_align_left,
  );
  static const AppIconData textAlignCenter = MaterialIconData(
    Icons.format_align_center,
  );
  static const AppIconData textAlignRight = MaterialIconData(
    Icons.format_align_right,
  );
  static const AppIconData letterSpacing = MaterialIconData(Icons.space_bar);
  static const AppIconData swatch = MaterialIconData(Icons.palette_outlined);

  // ── Theme/mode ──
  static const AppIconData darkMode = MaterialIconData(
    Icons.dark_mode_outlined,
  );
  static const AppIconData lightMode = MaterialIconData(
    Icons.light_mode_outlined,
  );
  static const AppIconData palette = MaterialIconData(Icons.palette);
  static const AppIconData pin = MaterialIconData(Icons.push_pin_outlined);

  // ── Connectivity ──
  static const AppIconData wifi = MaterialIconData(Icons.wifi);
  static const AppIconData wifiOff = MaterialIconData(Icons.wifi_off);
  static const AppIconData internet = MaterialIconData(Icons.language);

  // ── Misc / fallbacks ──
  static const AppIconData home = MaterialIconData(Icons.home_outlined);
  static const AppIconData bell = MaterialIconData(
    Icons.notifications_outlined,
  );
  static const AppIconData compass = MaterialIconData(Icons.explore);
  static const AppIconData addressBook = MaterialIconData(
    Icons.contacts_outlined,
  );
  static const AppIconData books = MaterialIconData(
    Icons.auto_stories_outlined,
  );
  static const AppIconData bookshelf = MaterialIconData(Icons.library_books);
}
