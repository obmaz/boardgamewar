import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'card_database.dart';

class ImageMatcher {
  static const String _cacheDirName = 'boardgame_thumbnails';
  static Directory? _cacheDir;
  static Map<String, List<int>>? _imageFeatures;

  /// 앱 시작 시 썸네일 이미지들을 다운로드하고 특징 추출
  static Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory(path.join(appDir.path, _cacheDirName));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    final entries = await CardDatabase.load();
    _imageFeatures = {};

    for (final entry in entries) {
      if (entry.thumbnailUrl != null && entry.thumbnailUrl!.isNotEmpty) {
        try {
          final features =
              await _getOrExtractFeatures(entry.id, entry.thumbnailUrl!);
          _imageFeatures![entry.id] = features;
        } catch (e) {
          // Individual thumbnail failures should not stop initialization.
        }
      }
    }
  }

  /// 이미지 특징 추출 (색상 히스토그램 기반)
  static Future<List<int>> _extractFeatures(img.Image image) async {
    const int bins = 16; // 각 채널당 16개 bin
    final histogram = List<int>.filled(bins * bins * bins, 0);

    for (final pixel in image) {
      final r = (pixel.r * bins) ~/ 256;
      final g = (pixel.g * bins) ~/ 256;
      final b = (pixel.b * bins) ~/ 256;
      final index = r * bins * bins + g * bins + b;
      if (index < histogram.length) {
        histogram[index]++;
      }
    }

    return histogram;
  }

  /// 이미지 다운로드 및 특징 추출 (캐시 활용)
  static Future<List<int>> _getOrExtractFeatures(String id, String url) async {
    final cacheFile = File(path.join(_cacheDir!.path, '$id.png'));

    img.Image? image;
    if (await cacheFile.exists()) {
      // 캐시된 이미지 사용
      final bytes = await cacheFile.readAsBytes();
      image = img.decodeImage(bytes);
    } else {
      // 이미지 다운로드
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        image = img.decodeImage(response.bodyBytes);
        if (image != null) {
          // 캐시에 저장
          await cacheFile.writeAsBytes(img.encodePng(image));
        }
      }
    }

    if (image != null) {
      return await _extractFeatures(image);
    } else {
      throw Exception('Failed to load image for $id');
    }
  }

  /// 캡처된 이미지와 가장 유사한 보드게임 찾기
  static Future<ImageMatchResult?> findBestMatch(Uint8List imageBytes) async {
    if (_imageFeatures == null || _imageFeatures!.isEmpty) {
      return null;
    }

    final capturedImage = img.decodeImage(imageBytes);
    if (capturedImage == null) return null;

    final capturedFeatures = await _extractFeatures(capturedImage);

    CardEntry? bestMatch;
    double bestSimilarity = 0.0;

    final entries = await CardDatabase.load();
    for (final entry in entries) {
      final features = _imageFeatures![entry.id];
      if (features != null) {
        final similarity = _calculateSimilarity(capturedFeatures, features);
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = entry;
        }
      }
    }

    // 유사도가 너무 낮으면 null 반환
    return bestSimilarity > 0.3
        ? ImageMatchResult(bestMatch!, bestSimilarity)
        : null;
  }

  /// 두 이미지 특징 벡터 간 유사도 계산 (코사인 유사도)
  static double _calculateSimilarity(List<int> features1, List<int> features2) {
    if (features1.length != features2.length) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < features1.length; i++) {
      dotProduct += features1[i] * features2[i];
      norm1 += features1[i] * features1[i];
      norm2 += features2[i] * features2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// 캐시 정리
  static Future<void> clearCache() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
    }
    _imageFeatures = null;
  }
}

class ImageMatchResult {
  final CardEntry entry;
  final double similarity;

  const ImageMatchResult(this.entry, this.similarity);
}
