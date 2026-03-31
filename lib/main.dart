import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'router.dart';
import 'services/storage_service.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
  ));

  final storage = await StorageService.init();
  final isDark = storage.isDarkMode();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        themeModeProvider.overrideWith((ref) => isDark ? ThemeMode.dark : ThemeMode.light),
      ],
      child: const GarudanApp(),
    ),
  );
}

class GarudanApp extends ConsumerWidget {
  const GarudanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Garudan',
      debugShowCheckedModeBanner: false,
      theme: GarudanTheme.light,
      darkTheme: GarudanTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
