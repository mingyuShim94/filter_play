import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' hide AssetManifest;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/asset_manifest.dart';

class DownloadProgress {
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String? currentFile;

  const DownloadProgress({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    this.currentFile,
  });

  DownloadProgress copyWith({
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? currentFile,
  }) {
    return DownloadProgress(
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      currentFile: currentFile ?? this.currentFile,
    );
  }

  @override
  String toString() {
    return 'DownloadProgress(progress: ${(progress * 100).toStringAsFixed(1)}%, $downloadedBytes/$totalBytes bytes)';
  }
}

class AssetDownloadService {
  static const String _manifestFileName = 'manifest.json';
  static const Duration _timeout = Duration(seconds: 30);

  static Future<String> _getAssetsDirectory(String gameId) async {
    final appDocuments = await getApplicationDocumentsDirectory();
    final assetsDir = Directory('${appDocuments.path}/assets/$gameId');
    
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }
    
    return assetsDir.path;
  }

  static Future<AssetManifest> loadManifestFromAssets(String manifestPath) async {
    try {
      final manifestString = await rootBundle.loadString(manifestPath);
      final manifestJson = json.decode(manifestString) as Map<String, dynamic>;
      return AssetManifest.fromJson(manifestJson);
    } catch (e) {
      throw Exception('애셋 매니페스트 로드 실패: $e');
    }
  }

  static Future<bool> isGameDownloaded(String gameId) async {
    try {
      final assetsDir = await _getAssetsDirectory(gameId);
      final manifestFile = File('$assetsDir/$_manifestFileName');
      
      if (!await manifestFile.exists()) {
        return false;
      }

      final manifestContent = await manifestFile.readAsString();
      final manifestJson = json.decode(manifestContent) as Map<String, dynamic>;
      final manifest = AssetManifest.fromJson(manifestJson);

      for (final asset in manifest.assets) {
        final assetFile = File('$assetsDir/${asset.url}');
        if (!await assetFile.exists()) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> downloadGameAssets(
    AssetManifest manifest,
    Stream<DownloadProgress> Function(DownloadProgress) onProgress,
  ) async {
    final assetsDir = await _getAssetsDirectory(manifest.gameId);
    final client = http.Client();
    
    try {
      int totalFiles = manifest.assets.length + 1; // +1 for manifest
      int downloadedFiles = 0;
      int totalBytes = 0;
      int downloadedBytes = 0;

      onProgress(DownloadProgress(
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: 1,
        currentFile: '파일 크기 계산 중...',
      ));

      for (final asset in manifest.assets) {
        try {
          final url = manifest.getFullUrl(asset.url);
          final headResponse = await client.head(Uri.parse(url)).timeout(_timeout);
          
          if (headResponse.statusCode == 200) {
            final contentLength = headResponse.headers['content-length'];
            if (contentLength != null) {
              totalBytes += int.parse(contentLength);
            }
          }
        } catch (e) {
          // HEAD 요청 실패시 무시하고 계속 진행
          continue;
        }
      }

      for (final asset in manifest.assets) {
        final url = manifest.getFullUrl(asset.url);
        final fileName = asset.url.split('/').last;
        final filePath = '$assetsDir/${asset.url}';
        final file = File(filePath);

        await file.parent.create(recursive: true);

        try {
          final response = await client.get(Uri.parse(url)).timeout(_timeout);
          
          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes);
            downloadedBytes += response.bodyBytes.length;
            downloadedFiles++;

            final progress = DownloadProgress(
              progress: downloadedFiles / totalFiles,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              currentFile: fileName,
            );

            onProgress(progress);
          } else {
            throw Exception('파일 다운로드 실패: $url (${response.statusCode})');
          }
        } catch (e) {
          throw Exception('$fileName 다운로드 실패: $e');
        }
      }

      final manifestFile = File('$assetsDir/$_manifestFileName');
      await manifestFile.writeAsString(json.encode(manifest.toJson()));
      downloadedFiles++;

      final finalProgress = DownloadProgress(
        progress: 1.0,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        currentFile: '다운로드 완료',
      );

      onProgress(finalProgress);
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> deleteGameAssets(String gameId) async {
    try {
      final assetsDir = await _getAssetsDirectory(gameId);
      final directory = Directory(assetsDir);
      
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('게임 애셋 삭제 실패: $e');
    }
  }

  static Future<String?> getLocalAssetPath(String gameId, String assetUrl) async {
    try {
      final assetsDir = await _getAssetsDirectory(gameId);
      final assetFile = File('$assetsDir/$assetUrl');
      
      if (await assetFile.exists()) {
        return assetFile.path;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<AssetManifest?> getLocalManifest(String gameId) async {
    try {
      final assetsDir = await _getAssetsDirectory(gameId);
      final manifestFile = File('$assetsDir/$_manifestFileName');
      
      if (await manifestFile.exists()) {
        final manifestContent = await manifestFile.readAsString();
        final manifestJson = json.decode(manifestContent) as Map<String, dynamic>;
        return AssetManifest.fromJson(manifestJson);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> verifyFileIntegrity(String filePath, String expectedHash) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString() == expectedHash;
    } catch (e) {
      return false;
    }
  }

  static Future<double> getDownloadSize(AssetManifest manifest) async {
    final client = http.Client();
    double totalSize = 0;

    try {
      for (final asset in manifest.assets) {
        try {
          final url = manifest.getFullUrl(asset.url);
          final headResponse = await client.head(Uri.parse(url)).timeout(_timeout);
          
          if (headResponse.statusCode == 200) {
            final contentLength = headResponse.headers['content-length'];
            if (contentLength != null) {
              totalSize += int.parse(contentLength);
            }
          }
        } catch (e) {
          // 개별 파일 크기 조회 실패시 무시
          continue;
        }
      }
    } catch (e) {
      // 전체 크기 조회 실패시 기본값 반환
      return -1;
    } finally {
      client.close();
    }

    return totalSize;
  }

  static String formatFileSize(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(0)} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}