import 'package:flutter/services.dart';

/// APK signing metadata — Mihon [ExtensionLoader.getSignatures] parity.
class ApkSigningInfo {
  const ApkSigningInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.signatures,
  });

  final String packageName;
  final String versionName;
  final int versionCode;

  /// SHA-256 hex digests of signing certificates (lowercase).
  final List<String> signatures;

  String? get primarySignature =>
      signatures.isEmpty ? null : signatures.last;

  factory ApkSigningInfo.fromMap(Map<dynamic, dynamic> map) {
    final rawSigs = map['signatures'];
    final sigs = <String>[];
    if (rawSigs is List) {
      for (final s in rawSigs) {
        if (s is String && s.isNotEmpty) sigs.add(s.toLowerCase());
      }
    }
    return ApkSigningInfo(
      packageName: map['packageName'] as String? ?? '',
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      signatures: sigs,
    );
  }
}

/// Reads signing certs from a private-sideloaded APK archive.
class ApkSignatureService {
  static const _channel = MethodChannel('com.koma.koma/system');

  Future<ApkSigningInfo> inspect(String apkPath) async {
    final raw = await _channel.invokeMethod<dynamic>('getApkSigningInfo', {
      'apkPath': apkPath,
    });
    if (raw is! Map) {
      throw StateError('getApkSigningInfo returned unexpected payload');
    }
    final info = ApkSigningInfo.fromMap(raw);
    if (info.packageName.isEmpty) {
      throw StateError('APK has no package name: $apkPath');
    }
    if (info.signatures.isEmpty) {
      throw StateError('APK is not signed: $apkPath');
    }
    return info;
  }
}
