import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/app_storage.dart';

import '../../../core/services/custom_font_service.dart';
import '../../../theme/theme_state.dart';
import '../../../theme/tokens/app_type.dart';

/// TTF/OTF path for the face the reader paints with, so KRE wrap uses it too.
///
/// Empty/null means "system default" (Roboto/Noto on Android).
Future<String?> readingFontFilePath(ThemeState theme) async {
  final customId = theme.readingFontId;
  if (customId != null) {
    final font = theme.customFontById(customId);
    if (font != null) {
      final path = await CustomFontService.instance.facePath(font);
      if (path != null) return path;
    }
  }
  final family = theme.effectiveReadingFontFamily;
  if (family == null || !GoogleFonts.asMap().containsKey(family)) {
    return null;
  }
  // Kick the google_fonts download/cache so a TTF lands in app-support.
  AppType.fontStyle(fontFamily: family);
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 4));
  } catch (_) {}
  for (var i = 0; i < 8; i++) {
    final path = await _cachedGoogleFontFile(family);
    if (path != null) return path;
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  return _cachedGoogleFontFile(family);
}

Future<String?> _cachedGoogleFontFile(String family) async {
  try {
    final dir = await AppStorage.support();
    if (!dir.existsSync()) return null;
    final key = family.toLowerCase();
    File? regular;
    File? any;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last.toLowerCase();
      if (!name.endsWith('.ttf') && !name.endsWith('.otf')) continue;
      if (!name.startsWith('${key}_') &&
          !name.startsWith('${key.replaceAll(' ', '')}_')) {
        continue;
      }
      any ??= entity;
      if (name.contains('regular') || name.contains('_400')) {
        regular = entity;
        break;
      }
    }
    return (regular ?? any)?.path;
  } catch (_) {
    return null;
  }
}
