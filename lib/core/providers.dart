import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import 'services/database_service.dart';
import 'services/extension_manager.dart';
import 'services/keiyoushi_service.dart';
import 'services/stats_service.dart';
import 'repositories/repositories.dart';
import '../features/library/library_provider.dart';
import '../features/reader/reader_provider.dart';
import '../features/snippets/snippets_provider.dart';
import '../theme/theme_provider.dart';

/// Riverpod DI graph. Replaces the old MultiProvider tree in main.dart.
///
/// The heavy singletons ([DatabaseService], [Isar], services) are created
/// once at startup and injected via [overrideWithValue] in the root
/// [ProviderScope] (see main.dart). The provider declarations below are
/// the read handles the rest of the app uses.
///
/// The four former ChangeNotifier providers are exposed through Riverpod's
/// [ChangeNotifierProvider] so their existing method/getter surface stays
/// intact — no internal rewrite needed. `ref.watch(themeProvider)` returns
/// the live [ThemeProvider] and rebuilds on notifyListeners(), exactly like
/// the old `context.watch<ThemeProvider>()`.

// ── Singletons (overridden at the root ProviderScope) ────────────────

final isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError('isarProvider must be overridden'),
);

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => throw UnimplementedError(
      'databaseServiceProvider must be overridden'),
);

final repositoriesProvider = Provider<Repositories>(
  (ref) => Repositories(ref.watch(isarProvider)),
);

final statsServiceProvider = Provider<StatsService>(
  (ref) => StatsService(ref.watch(databaseServiceProvider)),
);

final keiyoushiServiceProvider = Provider<KeiyoushiService>(
  (ref) => KeiyoushiService(),
);

final extensionManagerProvider = Provider<ExtensionManager>(
  (ref) => ExtensionManager(
    ref.watch(databaseServiceProvider),
    ref.watch(keiyoushiServiceProvider),
  ),
);

// ── Former ChangeNotifier providers ──────────────────────────────────

final themeProvider = ChangeNotifierProvider<ThemeProvider>(
  (ref) => throw UnimplementedError('themeProvider must be overridden'),
);

final libraryProvider = ChangeNotifierProvider<LibraryProvider>(
  (ref) => LibraryProvider(ref.watch(databaseServiceProvider)),
);

final readerProvider = ChangeNotifierProvider<ReaderProvider>(
  (ref) => ReaderProvider(
    ref.watch(databaseServiceProvider),
    ref.watch(statsServiceProvider),
  ),
);

final snippetsProvider = ChangeNotifierProvider<SnippetsProvider>(
  (ref) => SnippetsProvider(
    ref.watch(databaseServiceProvider),
    ref.watch(statsServiceProvider),
  ),
);
