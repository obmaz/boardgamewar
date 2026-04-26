import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/game_provider.dart';
import 'screens/camera_background.dart';
import 'screens/ui_layer.dart';
import 'utils/app_logger.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 로그 시스템 초기화
    await AppLogger.init();

    // Flutter 에러 캡처
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.log(
          'FLUTTER ERROR: ${details.exceptionAsString()}\nSTACK TRACE: ${details.stack}');
    };

    final gameProvider = GameProvider();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameProvider>.value(value: gameProvider)
        ],
        child: const ARCardBattlerApp(),
      ),
    );

    unawaited(gameProvider.initDatabase());
  }, (error, stack) {
    AppLogger.log('ASYNC ERROR: $error\nSTACK TRACE: $stack');
  });
}

class ARCardBattlerApp extends StatelessWidget {
  const ARCardBattlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Custom Card Battle',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const MainGameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainGameScreen extends StatelessWidget {
  const MainGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (game.currentPhase == GamePhase.start) {
              final shouldPop = await _showExitDialog(context);
              if (shouldPop == true) {
                game.quitGame();
              }
            } else {
              game.restartGame(); // 진행 중인 단계에서 start로 돌아감
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                if (game.currentPhase != GamePhase.start)
                  const CameraBackground(),
                const UILayer(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('게임 종료', style: TextStyle(color: Colors.white)),
        content: const Text('게임을 정말 종료하시겠습니까?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('종료', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
