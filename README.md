# Boardgame War

모바일 카메라로 실물 보드게임 카드를 스캐닝하여 실시간 자동 전투를 즐기는 Flutter 기반 오토 배틀러 애플리케이션입니다.

## 주요 기능

- **지능형 카드 인식**: Google ML Kit Text Recognition을 활용하여 카드 이름을 실시간으로 인식하고 카드 데이터를 매칭합니다.
- **이미지 매칭**: 카드 이미지를 비교하여 정확도 높은 카드 식별을 지원합니다.
- **보드게임 데이터베이스**: BoardGameGeek(BGG) API 연동 및 로컬 JSON 데이터베이스를 통해 보드게임 정보를 관리합니다.
- **자동 전투 엔진**: 스캔된 카드 정보를 바탕으로 적 유닛과 자동 턴제 전투를 진행하며 실시간 전투 로그를 표시합니다.
- **프리미엄 UI**: 카메라 프리뷰 위에 겹쳐지는 Glassmorphism 스타일의 애니메이션 인터페이스를 제공합니다.
- **크로스 플랫폼 지원**: 단일 코드베이스로 Android, iOS 및 Web 환경을 지원합니다.

## 기술 스택

- **Framework**: Flutter (SDK 3.4.0+)
- **State Management**: Provider
- **AI/ML**: Google ML Kit (Text Recognition)
- **External API**: BoardGameGeek (BGG) API
- **UI Architecture**: Glassmorphism 디자인 시스템

## 프로젝트 구조

```
lib/
  main.dart
  models/
    boardgame_info.dart       # 보드게임 정보 모델
    card_model.dart           # 카드 데이터 모델
    preset_cards.dart         # 프리셋 카드 정의
  providers/
    game_provider.dart        # 중앙 게임 상태 관리
  screens/
    camera_background.dart    # 카메라 AR 레이어
    card_select_screen.dart   # 카드 선택 화면
    ui_layer.dart             # 게임 상태별 UI 레이어 관리
  services/
    bgg_service.dart          # BoardGameGeek API 서비스
    card_database.dart        # 카드 데이터베이스 로드/파싱
    image_matcher.dart        # 카드 이미지 매칭 서비스
    local_boardgame_database.dart  # 로컬 보드게임 데이터 관리
  utils/
    app_logger.dart           # 공통 로거
    string_utils.dart         # 문자열 유틸리티

assets/
  boardgame_data/
    boardgames.json           # 보드게임 카드 데이터베이스
  images/
    title_background.jpg
    title_button_start.png
  logo/
    app_icon.png
```

## 시작하기

### 사전 요구 사항

- Flutter SDK (v3.4.0 이상)
- Android Studio 또는 VS Code (Flutter 플러그인 설치)
- 실기기(Android/iOS): 카메라 기능을 테스트하려면 실제 기기가 필요합니다.

### 실행 방법

1. 저장소 클론:
   ```bash
   git clone https://github.com/obmaz/boardgamewar.git
   ```
2. 패키지 설치:
   ```bash
   flutter pub get
   ```
3. 앱 실행:
   ```bash
   flutter run
   ```

## 개발 규칙

- **Hover/Focus 효과 제거**: 사용자 경험을 해치지 않기 위해 모든 영역에서 hover 및 focus 효과를 사용하지 않습니다.
- **디자인 원칙**: 고품질의 그라데이션, 유리 질감, 미세 애니메이션을 적용하여 프리미엄한 감각을 유지합니다.

---

> [!IMPORTANT]
> 이 프로젝트는 학습 및 포트폴리오 목적으로 제작되었으며, 카메라 권한 허용이 필수적입니다.
