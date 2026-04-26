import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/card_model.dart';
import '../models/boardgame_info.dart';
import '../models/preset_cards.dart';
import '../services/bgg_service.dart';
import '../services/card_database.dart';
import '../services/local_boardgame_database.dart';
import '../utils/string_utils.dart';
import '../utils/app_logger.dart';
import '../services/image_matcher.dart';

enum GamePhase { start, cardSelect, scan, battle, result }

class GameProvider extends ChangeNotifier {
  GamePhase _currentPhase = GamePhase.start;
  GamePhase get currentPhase => _currentPhase;

  UnitCard? playerCard;
  UnitCard? enemyCard;

  CameraController? cameraController;

  String battleLog = "전투 준비 완료!";
  bool isBattling = false;
  String resultTitle = "";
  String resultDesc = "";

  // 스캔 관련 상태
  bool isScanning = false;
  double currentSimilarity = 0.0;
  double? ocrSimilarity;
  double? imageSimilarity;
  CardEntry? currentScanResult;

  bool isDbLoaded = false;
  bool isLoadingBoardGameInfo = false;

  // OCR 텍스트 인식 영역 및 해상도 정보 (UI 테두리 표시용)
  List<Rect> recognizedRects = [];
  Size? scannedImageSize;
  BoardGameInfo? currentBoardGameInfo;
  List<BoardGameInfo> boardGameCandidates = [];
  String? _lastBoardGameLookupQuery;
  bool hasAttemptedBoardGameLookup = false;

  // 스캔 프레임 정보 (UI에서 정의된 프레임 범위)
  static const double scanFrameWidth = 280.0;
  static const double scanFrameHeight = 400.0;
  static const double scanFramePaddingTop = 140.0; // UI의 top 위치

  void setPhase(GamePhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void setCameraController(CameraController controller) {
    cameraController = controller;
    notifyListeners();
  }

  /// 앱 시작 시 카드 DB 로드
  Future<void> initDatabase() async {
    try {
      final entries = await CardDatabase.load();
      await LocalBoardGameDatabase.load();
      kPresetCards = entries.map(PresetCard.fromEntry).toList();
      isDbLoaded = true;
      notifyListeners();

      unawaited(_warmUpImageMatcher());
    } catch (e, stack) {
      AppLogger.log('INIT DATABASE ERROR: $e\nSTACK: $stack');
      isDbLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _warmUpImageMatcher() async {
    try {
      await ImageMatcher.initialize().timeout(const Duration(seconds: 8));
    } catch (e, stack) {
      AppLogger.log('IMAGE MATCHER WARMUP ERROR: $e\nSTACK: $stack');
    }
  }

  /// 카드 선택 화면으로 이동
  void goToCardSelect() {
    _resetScanState();
    setPhase(GamePhase.cardSelect);
  }

  /// 스캔 상태 초기화 (반복되는 로직 추출)
  void _resetScanState() {
    isScanning = false;
    currentScanResult = null;
    currentSimilarity = 0.0;
    ocrSimilarity = null;
    imageSimilarity = null;
    recognizedRects = [];
    scannedImageSize = null;
    currentBoardGameInfo = null;
    boardGameCandidates = [];
    isLoadingBoardGameInfo = false;
    _lastBoardGameLookupQuery = null;
    hasAttemptedBoardGameLookup = false;
  }

  /// 스캔 결과 초기화 (UI에서 호출)
  void clearScanResult() {
    _resetScanState();
    notifyListeners();
  }

  /// 스캔 재개 (다시 스캔할 때)
  void restartScan() {
    _resetScanState();
    startScan(); // 스캔 루프 다시 시작
  }

  /// 프리셋 보드게임을 플레이어로 선택하고 배틀 준비
  void selectPresetCard(PresetCard preset) {
    playerCard = preset.entry.toUnitCard();
    _prepareBattle(exclude: preset.id);
  }

  /// 로컬 보드게임 DB에서 id로 게임을 조회해 사용
  Future<void> selectCardById(String id) async {
    final entry = await CardDatabase.findById(id);
    if (entry == null) return;
    playerCard = entry.toUnitCard();
    _prepareBattle(exclude: id);
  }

  /// 배틀 준비 공통 로직
  void _prepareBattle({required String exclude}) {
    _spawnEnemyFromPreset(exclude: exclude);
    battleLog = "전투 준비 완료!";
    setPhase(GamePhase.battle);
  }

  /// 통합 스캔 메서드 (모바일이면 ML Kit, PC면 Mock 진행)
  Future<void> startScan() async {
    isScanning = true;
    currentSimilarity = 0.0;
    currentScanResult = null;
    setPhase(GamePhase.scan);

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      await Future.delayed(const Duration(seconds: 2));
      await _applyMockScanner();
      return;
    }

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

    try {
      AppLogger.log("Starting Continuous Scan...");
      final List<CardEntry> allBoardGames = await CardDatabase.load();

      while (isScanning && _currentPhase == GamePhase.scan) {
        // 카메라가 아직 준비되지 않은 경우 초기화를 대기하며 루프 유지
        if (cameraController == null ||
            !cameraController!.value.isInitialized) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        // 너무 빠른 연속 캡처 방지
        await Future.delayed(const Duration(milliseconds: 500));

        XFile? file;
        try {
          file = await cameraController!.takePicture();
          final inputImage = InputImage.fromFilePath(file.path);
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);

          // 촬영된 이미지의 실제 해상도를 구하고, 인식된 텍스트의 바운딩 박스를 저장
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frameInfo = await codec.getNextFrame();
          final decodedImage = frameInfo.image;
          scannedImageSize = Size(
              decodedImage.width.toDouble(), decodedImage.height.toDouble());

          // 스캔 프레임 범위 내의 텍스트만 필터링
          // UI에서 프레임이 top: 140으로 설정됨 → 이미지 해상도에 맞게 변환
          final imageWidth = decodedImage.width.toDouble();
          final imageHeight = decodedImage.height.toDouble();

          // UI 프레임 위치를 실제 화면 크기에 맞춰 이미지 좌표로 변환
          final previewSize = cameraController?.value.previewSize;
          final view = ui.PlatformDispatcher.instance.views.first;
          final uiSize = view.physicalSize / view.devicePixelRatio;
          final screenWidth = uiSize.width;
          final screenHeight = uiSize.height;

          final previewWidth = previewSize?.height.toDouble() ?? imageWidth;
          final previewHeight = previewSize?.width.toDouble() ?? imageHeight;
          final previewScale = (screenWidth / previewWidth)
                      .compareTo(screenHeight / previewHeight) >
                  0
              ? screenWidth / previewWidth
              : screenHeight / previewHeight;
          final dx = (screenWidth - previewWidth * previewScale) / 2;
          final dy = (screenHeight - previewHeight * previewScale) / 2;

          final frameLeft = (screenWidth - scanFrameWidth) / 2;
          final frameTop = scanFramePaddingTop;
          final frameRight = frameLeft + scanFrameWidth;
          final frameBottom = frameTop + scanFrameHeight;

          final frameLeftImg =
              ((frameLeft - dx) / previewScale).clamp(0.0, imageWidth);
          final frameTopImg =
              ((frameTop - dy) / previewScale).clamp(0.0, imageHeight);
          final frameRightImg =
              ((frameRight - dx) / previewScale).clamp(0.0, imageWidth);
          final frameBottomImg =
              ((frameBottom - dy) / previewScale).clamp(0.0, imageHeight);

          bool isInsideFrame(Rect rect) {
            return rect.left >= frameLeftImg &&
                rect.right <= frameRightImg &&
                rect.top >= frameTopImg &&
                rect.bottom <= frameBottomImg;
          }

          // 프레임 범위 내의 텍스트 블록만 필터링
          recognizedRects = recognizedText.blocks
              .where((block) {
                return isInsideFrame(block.boundingBox);
              })
              .map((b) => b.boundingBox)
              .toList();

          decodedImage.dispose(); // 메모리 누수 방지

          final String rawText = recognizedText.blocks
              .where((block) {
                return isInsideFrame(block.boundingBox);
              })
              .map((b) => b.text)
              .join(' ')
              .toLowerCase()
              .replaceAll('\n', ' ');

          // OCR 기반 매칭과 이미지 기반 매칭을 병렬로 수행
          final ocrMatchFuture = _findBestMatchByOCR(rawText, allBoardGames);
          final imageMatchFuture = ImageMatcher.findBestMatch(bytes);

          final ocrResult = await ocrMatchFuture;
          final imageResult = await imageMatchFuture;
          // OCR과 이미지 유사도 저장
          ocrSimilarity = ocrResult?.similarity;
          imageSimilarity = imageResult?.similarity;
          // OCR 결과와 이미지 결과를 비교
          CardEntry? bestMatch;
          double maxSimilarity = 0.0;

          if (ocrResult != null) {
            bestMatch = ocrResult.entry;
            maxSimilarity = ocrResult.similarity;
          }

          if (imageResult != null) {
            // 이미지 매칭은 OCR보다 낮은 가중치 적용
            final imageWeightedScore = imageResult.similarity * 0.7;
            if (bestMatch == null || imageWeightedScore > maxSimilarity) {
              bestMatch = imageResult.entry;
              maxSimilarity = imageWeightedScore;
            }
          }

          // 30% 이상일 때만 처리 (이미지 매칭은 더 낮은 임계값)
          if (maxSimilarity >= 0.3) {
            if (currentScanResult == null ||
                bestMatch?.id == currentScanResult?.id) {
              currentScanResult = bestMatch;
              currentSimilarity = maxSimilarity;
            } else if (maxSimilarity > currentSimilarity) {
              currentScanResult = bestMatch;
              currentSimilarity = maxSimilarity;
            }
          } else if (rawText.trim().isNotEmpty && currentScanResult == null) {
            // DB에 매칭되는게 없을 때 읽어온 텍스트로 즉석 보드게임 생성
            final words =
                rawText.trim().split(' ').where((w) => w.isNotEmpty).toList();
            String customName = words.take(2).join(' ');
            if (customName.length > 10) {
              customName = customName.substring(0, 10);
            }
            currentScanResult = CardDatabase.createGeneratedEntry(
              id: 'custom_scan_${DateTime.now().millisecondsSinceEpoch}',
              name: customName.isNotEmpty ? customName : "알 수 없는 보드게임",
              type: "custom",
            );
          }
          unawaited(_maybeLoadBoardGameInfo(rawText));
          notifyListeners();
        } catch (e, stack) {
          AppLogger.log("Loop scan error: $e\nSTACK: $stack");
        } finally {
          // 이미 찍은 파일 삭제 (용량 관리)
          if (file != null) {
            try {
              final f = File(file.path);
              if (await f.exists()) await f.delete();
            } catch (e) {
              AppLogger.log("Failed to delete captured image: $e");
            }
          }
        }
      }
    } catch (e, stack) {
      AppLogger.log("CRITICAL SCAN ERROR: $e\nSTACK: $stack");
      isScanning = false;
      notifyListeners();
    } finally {
      await textRecognizer.close();
    }
  }

  /// OCR 기반 보드게임 매칭
  Future<_MatchResult?> _findBestMatchByOCR(
    String rawText,
    List<CardEntry> allBoardGames,
  ) async {
    if (rawText.trim().isEmpty) return null;

    CardEntry? bestMatch;
    double maxSimilarity = 0.0;

    for (final entry in allBoardGames) {
      final normalizedCandidates = <String>{
        entry.name.toLowerCase(),
        if (entry.nameKo != null) entry.nameKo!.toLowerCase(),
      };
      double currentScore = 0.0;

      for (final candidate in normalizedCandidates) {
        if (candidate.isEmpty) continue;

        if (rawText.contains(candidate)) {
          currentScore = max(currentScore, 1.0);
          continue;
        }

        final words = rawText.split(' ');
        double maxNameScore = 0.0;
        for (final word in words) {
          if (word.length < 2) continue;
          final double score = StringUtils.similarity(word, candidate);
          if (score > maxNameScore) {
            maxNameScore = score;
          }
        }
        currentScore = max(currentScore, maxNameScore * 0.75);
      }

      if (currentScore > maxSimilarity) {
        maxSimilarity = currentScore;
        bestMatch = entry;
      }
    }

    return bestMatch != null ? _MatchResult(bestMatch, maxSimilarity) : null;
  }

  /// 인식된 보드게임 확정
  void confirmScanResult() {
    if (currentScanResult == null) return;

    isScanning = false;
    playerCard = _buildPlayerCardFromScanResult();
    _spawnEnemyFromPreset(exclude: currentScanResult!.id);
    battleLog = "전투 준비 완료!";

    setPhase(GamePhase.battle);
    _resetScanState();
  }

  Future<void> _applyMockScanner() async {
    final allCards = await CardDatabase.load();
    if (allCards.isNotEmpty) {
      currentScanResult = allCards.first;
      currentSimilarity = 0.95;
    } else {
      currentScanResult = CardDatabase.createGeneratedEntry(
        id: "test",
        name: "테스트 보드게임",
        type: "custom",
        imagePath: "assets/images/title_background.jpg",
      );
      currentSimilarity = 1.0;
    }
    unawaited(_maybeLoadBoardGameInfo(currentScanResult?.name ?? ''));
    notifyListeners();
  }

  UnitCard _buildPlayerCardFromScanResult() {
    final baseCard = currentScanResult!.toUnitCard();
    if (currentBoardGameInfo == null) return baseCard;

    return UnitCard(
      name: currentBoardGameInfo!.name,
      hp: baseCard.maxHp,
      atk: baseCard.atk,
      def: baseCard.def,
      skills: baseCard.skills,
      imagePath: baseCard.imagePath,
      imageUrl: currentBoardGameInfo!.thumbnailUrl,
    );
  }

  Future<void> _maybeLoadBoardGameInfo(String rawText) async {
    final lookupQuery = await _buildLookupQuery(rawText);
    if (lookupQuery == null) return;
    if (lookupQuery == _lastBoardGameLookupQuery) return;

    _lastBoardGameLookupQuery = lookupQuery;
    hasAttemptedBoardGameLookup = true;
    isLoadingBoardGameInfo = true;
    notifyListeners();

    try {
      final preferredQuery = _preferredBoardGameQuery(lookupQuery);
      final candidates =
          await BggService.searchBoardGameCandidates(preferredQuery);
      boardGameCandidates = candidates;
      currentBoardGameInfo = candidates.isNotEmpty ? candidates.first : null;

      if (currentBoardGameInfo != null &&
          _isGeneratedScanResult(currentScanResult)) {
        currentScanResult = CardDatabase.createGeneratedEntry(
          id: 'bgg_${currentBoardGameInfo!.bggId}',
          name: currentBoardGameInfo!.name,
          type: 'external',
        );
      }
    } catch (e, stack) {
      AppLogger.log('BGG lookup error: $e\nSTACK: $stack');
    } finally {
      isLoadingBoardGameInfo = false;
      notifyListeners();
    }
  }

  Future<String?> _buildLookupQuery(String rawText) async {
    final cleaned =
        rawText.replaceAll('&', ' & ').replaceAll(':', ' ').replaceAllMapped(
              RegExp(r'[^a-zA-Z0-9가-힣\s:&-]'),
              (_) => ' ',
            );
    const blockedWords = {
      'boardgame',
      'game',
      'edition',
      'board',
      'korea',
      'studio',
      'games',
      '더',
      '보드게임',
      '게임',
      '한글판',
      '코리아',
      '영문판',
      '확장',
    };
    final words = cleaned
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .where((token) => !blockedWords.contains(token.toLowerCase()))
        .take(7)
        .toList();
    if (words.isEmpty) return null;
    final rawQuery = words.join(' ');
    final localMatch = await LocalBoardGameDatabase.findBestMatch(rawQuery);
    if (localMatch != null) {
      return localMatch.entry.name;
    }
    return rawQuery;
  }

  String _preferredBoardGameQuery(String lookupQuery) {
    final currentName = currentScanResult?.name.trim();
    if (currentName != null &&
        currentName.isNotEmpty &&
        !_isGeneratedScanResult(currentScanResult)) {
      return currentName;
    }
    return lookupQuery;
  }

  void selectBoardGameCandidate(BoardGameInfo info) {
    currentBoardGameInfo = info;
    if (_isGeneratedScanResult(currentScanResult)) {
      currentScanResult = CardDatabase.createGeneratedEntry(
        id: 'bgg_${info.bggId}',
        name: info.name,
        type: 'external',
      );
    }
    notifyListeners();
  }

  bool _isGeneratedScanResult(CardEntry? entry) {
    if (entry == null) return false;
    return entry.id.startsWith('custom_scan_') || entry.id.startsWith('bgg_');
  }

  void _spawnEnemyFromPreset({String? exclude}) {
    final random = Random();
    final candidates = kPresetCards.where((p) => p.id != exclude).toList();
    if (candidates.isEmpty) {
      final defaults = CardDatabase.createGeneratedEntry(
        id: 'fallback_enemy',
        name: "심연의 수호자",
      );
      enemyCard = UnitCard(
        name: defaults.name,
        hp: defaults.hp,
        atk: defaults.atkMin +
            random.nextInt(defaults.atkMax - defaults.atkMin + 1),
        def: defaults.def,
        imagePath: defaults.imagePath,
      );
    } else {
      final chosen = candidates[random.nextInt(candidates.length)];
      enemyCard = chosen.entry.toUnitCard(random: random);
    }
  }

  Future<void> startBattle() async {
    if (isBattling || playerCard == null || enemyCard == null) return;

    isBattling = true;
    notifyListeners();

    while (!playerCard!.isDead && !enemyCard!.isDead && isBattling) {
      await Future.delayed(const Duration(seconds: 1));
      if (!isBattling) break;

      final int pDmg = max(1, playerCard!.atk - enemyCard!.def);
      enemyCard!.takeDamage(pDmg);
      battleLog = "${playerCard!.name}의 공격! $pDmg 피해를 입혔다.";
      notifyListeners();

      if (enemyCard!.isDead) {
        resultTitle = "승리!";
        resultDesc = "${enemyCard!.name}을(를) 물리쳤습니다!";
        isBattling = false;
        setPhase(GamePhase.result);
        break;
      }

      await Future.delayed(const Duration(seconds: 1));
      if (!isBattling) break;

      final int eDmg = max(1, enemyCard!.atk - playerCard!.def);
      playerCard!.takeDamage(eDmg);
      battleLog = "${enemyCard!.name}의 반격! $eDmg 피해를 입었다.";
      notifyListeners();

      if (playerCard!.isDead) {
        resultTitle = "패배...";
        resultDesc = "${playerCard!.name}이(가) 파괴되었습니다.";
        isBattling = false;
        setPhase(GamePhase.result);
        break;
      }
    }
  }

  void _resetGameState() {
    isBattling = false;
    playerCard = null;
    enemyCard = null;
  }

  void restartGame() {
    _resetGameState();
    setPhase(GamePhase.start);
  }

  void quitGame() {
    _resetGameState();
    setPhase(GamePhase.start);
    SystemNavigator.pop(); // 앱을 완전히 종료
  }
}

class _MatchResult {
  final CardEntry entry;
  final double similarity;

  const _MatchResult(this.entry, this.similarity);
}
