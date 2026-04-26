# Flutter wrapper 유지
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# google_mlkit_text_recognition: 언어별 옵션 클래스는 선택적 의존성이므로
# R8이 클래스를 찾지 못해도 빌드가 중단되지 않도록 dontwarn 처리합니다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit Commons
-dontwarn com.google_mlkit_commons.**
-keep class com.google_mlkit_commons.** { *; }

# ML Kit Text Recognition 핵심 클래스 유지
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.common.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Flutter 엔진 내부적으로 참조하나 Play Store APK가 아닌 경우 포함되지 않는
# Google Play Core (Deferred Components / Split Install) 클래스들을 무시합니다.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
