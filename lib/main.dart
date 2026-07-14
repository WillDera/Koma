import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/database_service.dart';
import 'core/services/stats_service.dart';
import 'features/library/library_provider.dart';
import 'features/reader/reader_provider.dart';
import 'features/snippets/snippets_provider.dart';
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = await DatabaseService.getInstance();
  final statsService = StatsService(dbService);
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final libraryProvider = LibraryProvider(dbService);
  await libraryProvider.init();
  final readerProvider = ReaderProvider(dbService, statsService);
  final snippetsProvider = SnippetsProvider(dbService, statsService);

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        Provider<StatsService>.value(value: statsService),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider),
        ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
        ChangeNotifierProvider<SnippetsProvider>.value(value: snippetsProvider),
      ],
      child: const StashReaderApp(),
    ),
  );
}
