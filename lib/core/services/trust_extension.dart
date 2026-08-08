import 'package:shared_preferences/shared_preferences.dart';

import '../models/extension_repo.dart';
import 'apk_signature_service.dart';

/// Mihon [TrustExtension] parity for private-sideloaded APKs.
///
/// Trusted when:
/// 1. Any APK signature fingerprint is in a repo's [ExtensionRepo.signingKey], or
/// 2. Key `"$pkg:$versionCode:$fingerprint"` is in the user-trusted set.
class TrustExtension {
  static const _prefsKey = 'trusted_extensions';

  /// Repo signing fingerprints currently known (lowercase hex).
  Set<String> _repoFingerprints = {};

  void updateRepoFingerprints(Iterable<ExtensionRepo> repos) {
    _repoFingerprints = {
      for (final r in repos)
        if (r.signingKey != null && r.signingKey!.trim().isNotEmpty)
          r.signingKey!.trim().toLowerCase(),
    };
  }

  Future<bool> isTrusted(ApkSigningInfo info) async {
    if (info.signatures.isEmpty) return false;
    if (info.signatures.any(_repoFingerprints.contains)) return true;

    final primary = info.primarySignature;
    if (primary == null) return false;
    final key = _key(info.packageName, info.versionCode, primary);
    final prefs = await SharedPreferences.getInstance();
    final trusted = prefs.getStringList(_prefsKey) ?? const [];
    return trusted.contains(key);
  }

  /// Trust this package version (replaces prior versions for the same pkg).
  Future<void> trust(ApkSigningInfo info) async {
    final primary = info.primarySignature;
    if (primary == null) return;
    final prefs = await SharedPreferences.getInstance();
    final next = <String>{
      for (final e in prefs.getStringList(_prefsKey) ?? const <String>[])
        if (!e.startsWith('${info.packageName}:')) e,
    };
    next.add(_key(info.packageName, info.versionCode, primary));
    await prefs.setStringList(_prefsKey, next.toList(growable: false));
  }

  Future<void> revokeAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static String _key(String pkg, int versionCode, String fingerprint) =>
      '$pkg:$versionCode:${fingerprint.toLowerCase()}';
}

/// Thrown when an APK is present but not trusted — caller shows Trust dialog.
class UntrustedExtensionException implements Exception {
  UntrustedExtensionException(this.info, {this.message});

  final ApkSigningInfo info;
  final String? message;

  @override
  String toString() =>
      message ??
      'Untrusted extension ${info.packageName} '
          '(${info.versionName} / ${info.versionCode})';
}
