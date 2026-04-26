import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/boardgame_info.dart';
import '../providers/game_provider.dart';
import '../models/card_model.dart';
import 'card_select_screen.dart';
import '../utils/app_logger.dart';

const double _scanFrameTop = 140.0;
const double _scanFrameWidth = 280.0;
const double _scanFrameHeight = 400.0;
const double _scanFrameRadius = 30.0;

class UILayer extends StatelessWidget {
  const UILayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, child) {
        return Stack(
          children: [
            if (game.currentPhase == GamePhase.start)
              _buildStartScreen(context, game),
            if (game.currentPhase == GamePhase.cardSelect)
              const CardSelectScreen(),
            if (game.currentPhase == GamePhase.scan) _buildScanScreen(game),
            if (game.currentPhase == GamePhase.battle ||
                game.currentPhase == GamePhase.result)
              _buildBattleScreen(game),
            if (game.currentPhase == GamePhase.result) _buildResultModal(game),
          ],
        );
      },
    );
  }

  Widget _buildStartScreen(BuildContext context, GameProvider game) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/title_background.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        color: Color(0xFF0F0F1A),
      ),
      child: Stack(
        children: [
          // 배경 장식 (서브 네온 효과)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.1),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 메인 액션 버튼 (시작)
                  _buildMenuButton(
                    onPressed: game.startScan,
                    imagePath: 'assets/images/title_button_start.png',
                  ),
                  const SizedBox(height: 40),

                  // 하단 기타 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (AppLogger.logs.isNotEmpty)
                        IconButton(
                          onPressed: () => _showErrorLog(context),
                          icon: const Icon(Icons.bug_report,
                              color: Colors.orangeAccent),
                          tooltip: "로그 확인",
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required VoidCallback onPressed,
    required String imagePath,
  }) {
    return Container(
      width: 308,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Ink(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.fitWidth,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const AspectRatio(
                aspectRatio: 3.5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          '시작하기',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF8B4A00),
                            shadows: [
                              Shadow(
                                color: Color(0xCCFFF6CF),
                                blurRadius: 12,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorLog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('에러 로그', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              AppLogger.logs.join('\n\n'),
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => AppLogger.clearLogs().then((_) {
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            child:
                const Text('로그 삭제', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => AppLogger.shareLogs(),
            child: const Text('로그 공유하기',
                style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanScreen(GameProvider game) {
    final similarityPercent = (game.currentSimilarity * 100).toInt();
    final hasMatch = game.currentScanResult != null;
    final boardGameInfo = game.currentBoardGameInfo;
    final hasCandidates = game.boardGameCandidates.length > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final safeTop = mediaQuery.padding.top;
        final safeBottom = mediaQuery.padding.bottom;
        final topGuideTop = safeTop + 12.0;
        final buttonBottom = safeBottom + 24.0;
        const buttonHeight = 48.0;
        final resultTop = _scanFrameTop + _scanFrameHeight + 28.0;
        final resultBottom = buttonBottom + buttonHeight + 18.0;
        final resultHeight = (constraints.maxHeight -
                resultTop -
                resultBottom -
                8.0)
            .clamp(112.0, 232.0);

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScanFrameOverlayPainter(),
              ),
            ),
            if (game.recognizedRects.isNotEmpty && game.scannedImageSize != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: _TextBoundingBoxPainter(
                    rects: game.recognizedRects,
                    imageSize: game.scannedImageSize!,
                  ),
                ),
              ),
            Positioned(
              top: topGuideTop,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    hasMatch ? "보드게임이 감지되었습니다!" : "보드게임을 스캔 중입니다...",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "프레임 안에 보드게임 이름을 위치시켜주세요.",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14),
                  ),
                ],
              ),
            ),
            Positioned(
              top: safeTop + 12,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: TextButton.icon(
                  onPressed: game.goToCardSelect,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.view_carousel_rounded, size: 18),
                  label: const Text(
                    '보드게임 선택',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: _scanFrameTop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _scanFrameWidth,
                  height: _scanFrameHeight,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: hasMatch
                          ? Colors.greenAccent
                          : Colors.white.withValues(alpha: 0.3),
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(_scanFrameRadius),
                  ),
                  child: hasMatch
                      ? const SizedBox.shrink()
                      : Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (hasMatch)
              Positioned(
                left: 0,
                right: 0,
                top: resultTop,
                child: Container(
                  height: resultHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildScanPreviewImage(
                                localImagePath: game.currentScanResult!.imagePath,
                                thumbnailUrl: boardGameInfo?.thumbnailUrl,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      game.currentScanResult!.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      children: [
                                        if (game.ocrSimilarity != null)
                                          _scanMetric(
                                            'OCR',
                                            '${(game.ocrSimilarity! * 100).toInt()}%',
                                            Colors.blueAccent,
                                          ),
                                        if (game.imageSimilarity != null)
                                          _scanMetric(
                                            '이미지',
                                            '${(game.imageSimilarity! * 100).toInt()}%',
                                            Colors.orangeAccent,
                                          ),
                                        _scanMetric(
                                          '최종',
                                          '$similarityPercent%',
                                          Colors.greenAccent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (game.isLoadingBoardGameInfo)
                            _buildLookupStateText(
                              title: '보드게임 정보를 찾는 중',
                              body: 'BGG에서 평점, 랭크, 가격 정보를 조회하고 있습니다.',
                              accent: Colors.lightBlueAccent,
                            )
                          else if (boardGameInfo != null)
                            _buildBoardGameDetailsText(boardGameInfo)
                          else if (game.hasAttemptedBoardGameLookup)
                            _buildLookupStateText(
                              title: '추가 정보를 찾지 못했습니다',
                              body:
                                  '보드게임 이름은 인식했지만 BGG에서 확실한 일치 항목을 찾지 못했습니다. 상자 제목을 더 정면에서 스캔해보세요.',
                              accent: Colors.amberAccent,
                            ),
                          if (hasCandidates) ...[
                            const SizedBox(height: 12),
                            _buildCandidateChooser(game),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (hasMatch)
              Positioned(
                left: 24,
                right: 24,
                bottom: buttonBottom + 2,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: game.confirmScanResult,
                        child: const Text("시작",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBattleScreen(GameProvider game) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (game.enemyCard != null)
            _buildCard(game.enemyCard!, isEnemy: true),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  game.battleLog,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (game.playerCard != null)
            _buildCard(game.playerCard!, isEnemy: false),
          const SizedBox(height: 10),
          if (!game.isBattling && game.currentPhase == GamePhase.battle)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: game.startBattle,
              child: const Text("공격 시작",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _buildBoardGameSummary(BoardGameInfo info) {
    final parts = <String>[];
    if (info.averageRating != null) {
      parts.add('평점 ${info.averageRating!.toStringAsFixed(1)}');
    }
    if (info.rank != null) {
      parts.add('랭크 #${info.rank}');
    }
    if (info.minPriceUsd != null) {
      parts.add('\$${info.minPriceUsd!.toStringAsFixed(2)}');
    }
    if (info.minPlayers != null && info.maxPlayers != null) {
      parts.add('${info.minPlayers}-${info.maxPlayers}인');
    }
    if (info.playingTime != null) {
      parts.add('${info.playingTime}분');
    }
    if (parts.isEmpty && info.publisher != null) {
      parts.add(info.publisher!);
    }
    return parts.join(' · ');
  }

  Widget _buildBoardGameDetailsText(BoardGameInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BGG 정보',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _buildBoardGameSummary(info),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _buildBoardGameInfoChips(info),
        ),
      ],
    );
  }

  Widget _buildLookupStateText({
    required String title,
    required String body,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildCandidateChooser(GameProvider game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '비슷한 후보',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: game.boardGameCandidates.map((candidate) {
              final isSelected =
                  game.currentBoardGameInfo?.bggId == candidate.bggId;
              return ChoiceChip(
                label: Text(candidate.name),
                selected: isSelected,
                onSelected: (_) => game.selectBoardGameCandidate(candidate),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                selectedColor: Colors.greenAccent.withValues(alpha: 0.22),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.greenAccent : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected
                      ? Colors.greenAccent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanPreviewImage({
    required String localImagePath,
    String? thumbnailUrl,
  }) {
    final frame = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24, width: 1),
    );

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Container(
        width: 80,
        height: 100,
        decoration: frame,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return localImagePath.startsWith('http')
                  ? Image.network(localImagePath, fit: BoxFit.cover)
                  : Image.asset(localImagePath, fit: BoxFit.cover);
            },
          ),
        ),
      );
    }

    return Container(
      width: 80,
      height: 100,
      decoration: frame,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: localImagePath.startsWith('http')
            ? Image.network(localImagePath, fit: BoxFit.cover)
            : Image.asset(localImagePath, fit: BoxFit.cover),
      ),
    );
  }

  List<Widget> _buildBoardGameInfoChips(BoardGameInfo info) {
    final chips = <Widget>[];

    if (info.yearPublished != null) {
      chips.add(_infoChip('${info.yearPublished}년'));
    }
    if (info.publisher != null && info.publisher!.isNotEmpty) {
      chips.add(_infoChip(info.publisher!));
    }
    chips.add(_infoChip('신뢰도 ${(info.confidence * 100).round()}%'));
    chips.add(_infoChip('BGG #${info.bggId}'));

    return chips;
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _scanMetric(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(UnitCard card, {required bool isEnemy}) {
    final hpPercent = card.hp / card.maxHp;
    final hpColor = isEnemy ? Colors.red : Colors.green;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isEnemy ? const Color(0xFF2A1B38) : const Color(0xFF1B2A38),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isEnemy
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.blue.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (card.imagePath != null || card.imageUrl != null) ...[
            _buildBattleCardImage(card),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              _statBadge("DEF", card.def.toString(), Colors.blue),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: card.skills.isEmpty
                ? [_skillBadge("자동 전투", '${card.atk}', Colors.orange)]
                : card.skills
                    .map((skill) => _skillBadge(
                          skill.name,
                          skill.damage.toString(),
                          Colors.orange,
                        ))
                    .toList(),
          ),
          const SizedBox(height: 15),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(5)),
              ),
              FractionallySizedBox(
                widthFactor: hpPercent.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                      color: hpColor, borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text("${card.hp} / ${card.maxHp}",
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBattleCardImage(UnitCard card) {
    final frame = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white24, width: 1),
    );

    Widget imageWidget;
    if (card.imageUrl != null && card.imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        card.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return card.imagePath != null
              ? (card.imagePath!.startsWith('http')
                  ? Image.network(card.imagePath!, fit: BoxFit.cover)
                  : Image.asset(card.imagePath!, fit: BoxFit.cover))
              : Container(color: Colors.black26);
        },
      );
    } else if (card.imagePath != null) {
      imageWidget = card.imagePath!.startsWith('http')
          ? Image.network(card.imagePath!, fit: BoxFit.cover)
          : Image.asset(card.imagePath!, fit: BoxFit.cover);
    } else {
      imageWidget = Container(color: Colors.black26);
    }

    return Container(
      width: 92,
      height: 128,
      decoration: frame,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageWidget,
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _skillBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildResultModal(GameProvider game) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                game.resultTitle,
                style: TextStyle(
                  color: game.resultTitle == "승리!" ? Colors.yellow : Colors.red,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                game.resultDesc,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: game.restartGame,
                child: const Text("다시 하기",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: game.quitGame,
                child: Text(
                  "게임 종료하기",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFrameOverlayPainter extends CustomPainter {
  // 스캔 프레임 상수
  @override
  void paint(Canvas canvas, Size size) {
    // 화면 중앙 상단에 프레임 위치 계산
    final frameLeft = (size.width - _scanFrameWidth) / 2;
    final frameTop = _scanFrameTop;
    final frameRect =
        Rect.fromLTWH(frameLeft, frameTop, _scanFrameWidth, _scanFrameHeight);
    final frameRRect = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(_scanFrameRadius),
    );

    // 전체 화면에서 라운드 프레임 영역만 비워서 코너 바깥도 어둡게 처리
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(frameRRect);

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanFrameOverlayPainter oldDelegate) => false;
}

class _TextBoundingBoxPainter extends CustomPainter {
  final List<Rect> rects;
  final Size imageSize;

  _TextBoundingBoxPainter({required this.rects, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellowAccent.withValues(alpha: 0.8);

    // 카메라 프리뷰가 화면을 꽉 채우는(BoxFit.cover) 상태라고 가정하고 화면 비율에 맞춰 좌표 변환
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double dx = (size.width - imageSize.width * scale) / 2;
    final double dy = (size.height - imageSize.height * scale) / 2;

    for (final rect in rects) {
      final left = rect.left * scale + dx;
      final top = rect.top * scale + dy;
      final right = rect.right * scale + dx;
      final bottom = rect.bottom * scale + dy;
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TextBoundingBoxPainter oldDelegate) {
    return oldDelegate.rects != rects || oldDelegate.imageSize != imageSize;
  }
}
