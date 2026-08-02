import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A unified icon descriptor that can represent either a Material icon
/// ([IconData]) or a Hugeicon ([List<List<dynamic>>]).
///
/// This lets the design system use premium Hugeicons stroke-rounded icons
/// for primary navigation and key UI, while still allowing Material icons
/// anywhere a Hugeicon equivalent isn't available.
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

/// A Hugeicon backed by SVG path data.
class HugeIconData extends AppIconData {
  final List<List<dynamic>> icon;
  final double? strokeWidth;

  const HugeIconData(this.icon, {this.strokeWidth});

  @override
  Widget render({double? size, Color? color, Key? key}) {
    return HugeIcon(
      key: key,
      icon: icon,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is HugeIconData && other.icon == icon);

  @override
  int get hashCode => icon.hashCode;
}

/// A widget that renders any [AppIconData]. This is the single entry point
/// for icon rendering throughout the app — call-sites pass an [AppIconData]
/// and this widget handles the Material-vs-Hugeicon dispatch.
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

// ─── Aethelgard icon set ────────────────────────────────────────────────
// Canonical icon mappings for the redesign. All primary navigation and key
// UI elements use Hugeicons stroke-rounded variants for a premium, consistent
// line-icon aesthetic. These are the "source of truth" — screens should
// reference these rather than raw HugeIcons/Material constants.
class AppIcons {
  AppIcons._();

  // ── Navigation ──
  static const AppIconData library = HugeIconData(
    HugeIcons.strokeRoundedBookOpen01,
  );
  static const AppIconData libraryActive = HugeIconData(
    HugeIcons.strokeRoundedBookOpen02,
  );
  static const AppIconData history = HugeIconData(
    HugeIcons.strokeRoundedClock01,
  );
  static const AppIconData historyActive = HugeIconData(
    HugeIcons.strokeRoundedClock02,
  );
  static const AppIconData snippets = HugeIconData(
    HugeIcons.strokeRoundedBookmark01,
  );
  static const AppIconData snippetsActive = HugeIconData(
    HugeIcons.strokeRoundedBookmark02,
  );
  static const AppIconData discover = HugeIconData(
    HugeIcons.strokeRoundedCompass01,
  );
  static const AppIconData discoverActive = HugeIconData(
    HugeIcons.strokeRoundedCompass,
  );
  static const AppIconData search = HugeIconData(
    HugeIcons.strokeRoundedSearch01,
  );
  static const AppIconData searchActive = HugeIconData(
    HugeIcons.strokeRoundedSearch02,
  );
  static const AppIconData settings = HugeIconData(
    HugeIcons.strokeRoundedSettings01,
  );
  static const AppIconData settingsActive = HugeIconData(
    HugeIcons.strokeRoundedSettings02,
  );

  // ── Actions ──
  static const AppIconData add = HugeIconData(HugeIcons.strokeRoundedAdd01);
  static const AppIconData addCircle = HugeIconData(
    HugeIcons.strokeRoundedAddCircle,
  );
  static const AppIconData back = HugeIconData(
    HugeIcons.strokeRoundedArrowLeft02,
  );
  static const AppIconData forward = HugeIconData(
    HugeIcons.strokeRoundedArrowRight02,
  );
  static const AppIconData close = HugeIconData(
    HugeIcons.strokeRoundedCancel01,
  );
  static const AppIconData moreHorizontal = HugeIconData(
    HugeIcons.strokeRoundedMoreHorizontal,
  );
  static const AppIconData moreVertical = HugeIconData(
    HugeIcons.strokeRoundedMoreVertical,
  );
  static const AppIconData share = HugeIconData(HugeIcons.strokeRoundedShare04);
  static const AppIconData play = HugeIconData(HugeIcons.strokeRoundedPlay);
  static const AppIconData playCircle = HugeIconData(
    HugeIcons.strokeRoundedPlayCircle,
  );
  static const AppIconData refresh = HugeIconData(
    HugeIcons.strokeRoundedRefresh01,
  );
  static const AppIconData reload = HugeIconData(HugeIcons.strokeRoundedReload);
  static const AppIconData download = HugeIconData(
    HugeIcons.strokeRoundedDownload04,
  );
  static const AppIconData upload = HugeIconData(
    HugeIcons.strokeRoundedArrowUp01,
  );
  static const AppIconData delete = HugeIconData(
    HugeIcons.strokeRoundedDelete02,
  );
  static const AppIconData edit = HugeIconData(
    HugeIcons.strokeRoundedPencilEdit01,
  );
  static const AppIconData filter = HugeIconData(
    HugeIcons.strokeRoundedFilterHorizontal,
  );
  static const AppIconData tune = HugeIconData(
    HugeIcons.strokeRoundedSlidersVertical,
  );
  static const AppIconData sort = HugeIconData(
    HugeIcons.strokeRoundedSortByUp01,
  );
  static const AppIconData grid = HugeIconData(HugeIcons.strokeRoundedGridView);
  static const AppIconData list = HugeIconData(HugeIcons.strokeRoundedListView);
  static const AppIconData menu = HugeIconData(HugeIcons.strokeRoundedMenu02);
  static const AppIconData check = HugeIconData(
    HugeIcons.strokeRoundedCheckmarkCircle02,
  );
  static const AppIconData expand = HugeIconData(HugeIcons.strokeRoundedExpand);
  static const AppIconData next = HugeIconData(HugeIcons.strokeRoundedNext);
  static const AppIconData previous = HugeIconData(
    HugeIcons.strokeRoundedPrevious,
  );

  // ── Content / status ──
  static const AppIconData book = HugeIconData(HugeIcons.strokeRoundedBook02);
  static const AppIconData bookOpen = HugeIconData(
    HugeIcons.strokeRoundedBookOpen01,
  );
  static const AppIconData bookmark = HugeIconData(
    HugeIcons.strokeRoundedBookmark02,
  );
  static const AppIconData bookmarkAdd = HugeIconData(
    HugeIcons.strokeRoundedBookmarkAdd01,
  );
  static const AppIconData star = HugeIconData(HugeIcons.strokeRoundedStar);
  static const AppIconData starHalf = HugeIconData(
    HugeIcons.strokeRoundedStarHalf,
  );
  static const AppIconData lock = HugeIconData(
    HugeIcons.strokeRoundedLockPassword,
  );
  static const AppIconData clock = HugeIconData(HugeIcons.strokeRoundedClock01);
  static const AppIconData calendar = MaterialIconData(
    Icons.calendar_today_outlined,
  );
  static const AppIconData schedule = HugeIconData(
    HugeIcons.strokeRoundedClock02,
  );
  static const AppIconData person = HugeIconData(HugeIcons.strokeRoundedUser02);
  static const AppIconData globe = HugeIconData(HugeIcons.strokeRoundedGlobe02);
  static const AppIconData translate = HugeIconData(
    HugeIcons.strokeRoundedTranslate,
  );
  static const AppIconData note = HugeIconData(
    HugeIcons.strokeRoundedNotebook01,
  );
  static const AppIconData alert = HugeIconData(
    HugeIcons.strokeRoundedAlertCircle,
  );
  static const AppIconData info = HugeIconData(
    HugeIcons.strokeRoundedInformationCircle,
  );
  static const AppIconData hourglass = HugeIconData(
    HugeIcons.strokeRoundedHourglass,
  );
  static const AppIconData loading = HugeIconData(
    HugeIcons.strokeRoundedLoading03,
  );
  static const AppIconData cloudLoading = HugeIconData(
    HugeIcons.strokeRoundedCloudLoading,
  );

  // ── Reader ──
  static const AppIconData textToSpeech = HugeIconData(
    HugeIcons.strokeRoundedSpeaker01,
  );
  static const AppIconData volumeHigh = HugeIconData(
    HugeIcons.strokeRoundedVolumeHigh,
  );
  static const AppIconData volumeLow = HugeIconData(
    HugeIcons.strokeRoundedVolumeLow,
  );
  static const AppIconData fullscreen = HugeIconData(
    HugeIcons.strokeRoundedMaximize01,
  );
  static const AppIconData fullscreenExit = HugeIconData(
    HugeIcons.strokeRoundedMinimize01,
  );
  static const AppIconData chapterList = HugeIconData(
    HugeIcons.strokeRoundedMenu01,
  );
  static const AppIconData brightness = HugeIconData(
    HugeIcons.strokeRoundedSun02,
  );
  static const AppIconData fontSize = HugeIconData(
    HugeIcons.strokeRoundedTextFont,
  );
  static const AppIconData textAlignLeft = HugeIconData(
    HugeIcons.strokeRoundedTextAlignLeft,
  );
  static const AppIconData textAlignCenter = HugeIconData(
    HugeIcons.strokeRoundedTextAlignCenter,
  );
  static const AppIconData textAlignRight = HugeIconData(
    HugeIcons.strokeRoundedTextAlignRight,
  );
  static const AppIconData letterSpacing = HugeIconData(
    HugeIcons.strokeRoundedLetterSpacing,
  );
  static const AppIconData swatch = HugeIconData(HugeIcons.strokeRoundedSwatch);

  // ── Theme/mode ──
  static const AppIconData darkMode = HugeIconData(
    HugeIcons.strokeRoundedMoon01,
  );
  static const AppIconData lightMode = HugeIconData(
    HugeIcons.strokeRoundedSun01,
  );
  static const AppIconData palette = HugeIconData(
    HugeIcons.strokeRoundedSwatch,
  );
  static const AppIconData pin = HugeIconData(HugeIcons.strokeRoundedPin);

  // ── Connectivity ──
  static const AppIconData wifi = HugeIconData(HugeIcons.strokeRoundedWifi01);
  static const AppIconData wifiOff = HugeIconData(
    HugeIcons.strokeRoundedWifiOff01,
  );
  static const AppIconData internet = HugeIconData(
    HugeIcons.strokeRoundedInternet,
  );

  // ── Misc / fallbacks ──
  static const AppIconData home = HugeIconData(HugeIcons.strokeRoundedHome02);
  static const AppIconData bell = HugeIconData(HugeIcons.strokeRoundedBellDot);
  static const AppIconData compass = HugeIconData(
    HugeIcons.strokeRoundedCompass,
  );
  static const AppIconData addressBook = HugeIconData(
    HugeIcons.strokeRoundedAddressBook,
  );
  static const AppIconData books = HugeIconData(HugeIcons.strokeRoundedBooks01);
  static const AppIconData bookshelf = HugeIconData(
    HugeIcons.strokeRoundedBookshelf01,
  );
}
