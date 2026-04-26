# ⚔️ AR Card Battler

모바일 카메라로 실물 카드를 스캐닝하여 실시간 증강 현실(AR) 전투를 즐기는 Flutter 기반 오토 배틀러 애플리케이션입니다.

## ✨ 주요 기능

- **지능형 카드 인식**: Google ML Kit의 Text Recognition을 활용하여 카드의 이름을 실시간으로 인식하고 카드 데이터를 매칭합니다.
- **프리미엄 AR UI**: 카메라 프리뷰 위에 겹쳐지는 세련된 유리 질감(Glassmorphism)과 다이나믹한 애니메이션 인터페이스를 제공합니다.
- **데이터 기반 시스템**: JSON 형식의 고도화된 카드 데이터베이스를 통해 수십 종의 유닛 스탯과 이미지를 관리합니다.
- **자동 전투 엔진**: 스캔된 카드 정보를 바탕으로 적 유닛과 자동으로 턴제 전투를 진행하며 실시간 전투 로그를 표시합니다.
- **크로스 플랫폼 지원**: 단일 코드베이스로 Android, iOS 및 데스크톱 환경(Windows, MacOS, Web)을 지원합니다.

## 🛠 기술 스택

- **Framework**: [Flutter](https://flutter.dev/) (SDK 3.4.0+)
- **State Management**: Provider
- **AI/ML**: Google ML Kit (Text Recognition)
- **UI Architecture**: Glassmorphism 디자인 시스템
- **Asset Pipeline**: JSON Card Database & Scalable Assets

## 📂 프로젝트 구조

- `lib/`
  - `models/`: 카드 및 전투 데이터 모델
  - `providers/`: `game_provider.dart`를 통한 중앙 상태 관리
  - `screens/`: 메인 화면 및 카메라 AR 레이어 화면
  - `services/`: OCR 인식 및 데이터 파싱 서비스
  - `utils/`: 공통 유틸리티 및 상수
- `assets/`
  - `card_db/`: 카드 데이터(`cards.json`) 및 리소스(이미지, QR 등)

## 🚀 시작하기

### 사전 요구 사항
- Flutter SDK (v3.4.0 이상)
- Android Studio 또는 VS Code (Flutter 플러그인 설치)
- 실기기(Android/iOS) : 카메라 기능을 테스트하려면 실제 기기가 필요합니다.

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

## 📜 개발 규칙 (User Guide)

- **Hover/Focus 효과 제거**: 사용자 경험을 해치지 않기 위해 모든 영역에서 hover 및 focus 효과를 사용하지 않습니다.
- **디자인 원칙**: 고품질의 그라데이션, 유리 질감, 그리고 미세 애니메이션을 적용하여 프리미엄한 감각을 유지합니다.

---

> [!IMPORTANT]
> 이 프로젝트는 학습 및 포트폴리오 목적으로 제작되었으며, 카메라 권한 허용이 필수적입니다.
