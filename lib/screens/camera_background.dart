import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/game_provider.dart';

class CameraBackground extends StatefulWidget {
  const CameraBackground({super.key});


  @override
  State<CameraBackground> createState() => _CameraBackgroundState();
}

class _CameraBackgroundState extends State<CameraBackground> {
  CameraController? _controller;
  bool _isReady = false;
  bool _isMockOnly = false;

  @override
  void initState() {
    super.initState();
    // PC (Web, Windows, macOS, Linux) 인 경우 카메라 초기화 생략
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _isMockOnly = true;
      _isReady = true;
    } else {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          debugPrint('Camera permission denied');
          if (mounted) {
            setState(() => _isReady = true);
          }
          return;
        }
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isReady = true);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) {
        // Provider에 컨트롤러 전달하여 ML Kit에서 접근 가능하게 함
        Provider.of<GameProvider>(context, listen: false).setCameraController(_controller!);
        setState(() => _isReady = true);
      }
    } catch (e) {
      debugPrint('Camera initialized failed: $e');
      if (mounted) {
        setState(() => _isReady = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    // PC 화면 등 카메라가 불필요/비활성화 된 경우
    if (_isMockOnly || _controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: const Color(0xFF0F0F1A),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monitor, size: 64, color: Colors.white24),
              SizedBox(height: 20),
              Text(
                "PC 환경 테스트 모드\n(카메라 연동 없음, Mock 실행)",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // 모바일 (Android/iOS) 실제 카메라 프리뷰
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize?.height ?? 1,
          height: _controller!.value.previewSize?.width ?? 1,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }
}
