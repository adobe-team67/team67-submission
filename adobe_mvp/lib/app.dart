import 'package:adobe_mvp/core/global.dart';
import 'package:adobe_mvp/features/files/files_screen.dart';
import 'package:adobe_mvp/features/learn/learn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/editor/editor_screen.dart';
import 'features/splash/splash_screen.dart';
import 'state/providers.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = GlobalConfig.loadFromLocal();
    ref.read(yoloProvider).initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.connectionState == ConnectionState.done;

        return MaterialApp(
          title: 'Adobe MVP',
          theme: AppTheme.darkTheme,     // Always loaded safely
          debugShowCheckedModeBanner: false,

          // Show skeleton loader until initialization is done
          home: isReady
              ? const SplashScreen()
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),

          routes: isReady
              ? {
                  '/home': (ctx) => const HomeScreen(),
                  '/editor': (ctx) => const EditorScreen(),
                  '/files': (ctx) => const FilesScreen(),
                  '/learn': (ctx) => const LearnScreen(),
                }
              : {}, // avoid null route tables
        );
      },
    );
  }
}
