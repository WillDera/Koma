import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the user's [RapidAPI](https://rapidapi.com/tribestick-tribestick-default/api/annas-archive-api) key.
const kAnnasArchiveRapidApiKeyPref = 'annas_archive_rapidapi_key';

/// SharedPreferences key for the Anna's Archive membership secret key (fast downloads).
const kAnnasArchiveSecretKeyPref = 'annas_archive_secret_key';

const _kRapidApiHost = 'annas-archive-api.p.rapidapi.com';

String get annasArchiveRapidApiHost => _kRapidApiHost;

Future<String?> readAnnasArchiveRapidApiKey([SharedPreferences? prefs]) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  final v = p.getString(kAnnasArchiveRapidApiKeyPref)?.trim();
  return v != null && v.isNotEmpty ? v : null;
}

Future<String?> readAnnasArchiveSecretKey([SharedPreferences? prefs]) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  final v = p.getString(kAnnasArchiveSecretKeyPref)?.trim();
  return v != null && v.isNotEmpty ? v : null;
}
