import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' hide AssetManifest;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/asset_manifest.dart';
import '../models/master_manifest.dart';

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

// 병렬 다운로드를 위한 Semaphore 클래스
class Semaphore {
  final int _maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this._maxCount) : _currentCount = _maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.addLast(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

class AssetDownloadService {
  static const String _manifestFileName = 'manifest.json';
  static const int _maxConcurrentDownloads = 4;
  
  // Singleton Dio 인스턴스
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
  ));
  
  static bool _isInitialized = false;
  
  static void _initializeDio() {
    if (_isInitialized) return; // 중복 초기화 방지
    
    // LogInterceptor 추가 (디버깅용)
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: true,
      responseHeader: false,
      logPrint: (object) => print('🌐 HTTP: $object'),
    ));
    
    // 재시도 인터셉터 추가
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        print('❌ Dio 오류 발생: ${error.type} - ${error.message}');
        print('   요청 URL: ${error.requestOptions.uri}');
        
        // 재시도 가능한 오류 타입 확인
        if (_shouldRetry(error) && error.requestOptions.extra['retryCount'] == null) {
          error.requestOptions.extra['retryCount'] = 1;
          print('🔄 재시도 시도 중...');
          
          try {
            await Future.delayed(const Duration(seconds: 1)); // 1초 대기
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } catch (retryError) {
            print('🔄 재시도 실패: $retryError');
          }
        }
        
        handler.next(error);
      },
    ));
    
    _isInitialized = true;
    print('✅ Dio 초기화 완료 (singleton)');
  }
  
  static bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.connectionError ||
           error.type == DioExceptionType.unknown;
  }

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
    print('⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐');
    print('🚀💥 게임 에셋 다운로드 시작: ${manifest.gameId} (${manifest.gameTitle})');
    print('📍🔥 Base URL: ${manifest.baseUrl}');
    print('📋⚡ 다운로드할 파일 수: ${manifest.assets.length}개');
    print('⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐');
    
    _initializeDio();
    final assetsDir = await _getAssetsDirectory(manifest.gameId);
    
    try {
      int totalFiles = manifest.assets.length + 1; // +1 for manifest
      int downloadedFiles = 0;
      int downloadedBytes = 0;

      onProgress(DownloadProgress(
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: 1,
        currentFile: '병렬 다운로드 시작...',
      ));

      print('⬇️ 병렬 파일 다운로드 시작 (최대 $_maxConcurrentDownloads개 동시)...');
      
      // 병렬 다운로드를 위한 Semaphore
      final semaphore = Semaphore(_maxConcurrentDownloads);
      final List<Future<Map<String, dynamic>>> downloadFutures = [];
      
      for (final asset in manifest.assets) {
        final future = semaphore.acquire().then((_) async {
          try {
            final url = manifest.getFullUrl(asset.url);
            final fileName = asset.url.split('/').last;
            final filePath = '$assetsDir/${asset.url}';
            final file = File(filePath);

            print('📥 다운로드 시작: ${asset.name} ($fileName)');
            await file.parent.create(recursive: true);

            final response = await _dio.get<List<int>>(
              url,
              options: Options(responseType: ResponseType.bytes),
            );
            
            if (response.statusCode == 200 && response.data != null) {
              await file.writeAsBytes(response.data!);
              final size = response.data!.length;
              
              print('   ✅ 파일 저장 완료: ${asset.name} (${formatFileSize(size.toDouble())})');
              
              return {
                'success': true,
                'fileName': fileName,
                'size': size,
              };
            } else {
              throw Exception('HTTP ${response.statusCode}');
            }
          } catch (e) {
            String errorMessage = '알 수 없는 오류';
            if (e is DioException) {
              errorMessage = _getDioErrorMessage(e);
            } else {
              errorMessage = e.toString();
            }
            
            print('   ❌ 다운로드 실패: ${asset.name} - $errorMessage');
            return {
              'success': false,
              'fileName': asset.url.split('/').last,
              'error': errorMessage,
            };
          } finally {
            semaphore.release();
          }
        });
        
        downloadFutures.add(future);
      }

      // 모든 다운로드 완료 대기하며 진행률 업데이트
      int totalBytes = 0;
      for (final future in downloadFutures) {
        final result = await future;
        downloadedFiles++;
        
        if (result['success'] == true) {
          downloadedBytes += result['size'] as int;
          totalBytes += result['size'] as int;
        } else {
          throw Exception('${result['fileName']} 다운로드 실패: ${result['error']}');
        }

        final progress = DownloadProgress(
          progress: downloadedFiles / totalFiles,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes > 0 ? totalBytes : downloadedBytes,
          currentFile: result['fileName'],
        );

        onProgress(progress);
      }

      // 매니페스트 파일 저장
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
      print('🎉 모든 파일 다운로드 완료: ${manifest.assets.length}개 파일, ${formatFileSize(downloadedBytes.toDouble())}');
      
    } catch (e) {
      rethrow;
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
    print('📏 다운로드 크기 계산 시작: ${manifest.gameId}');
    print('📍 Base URL: ${manifest.baseUrl}');
    
    _initializeDio();
    double totalSize = 0;

    try {
      // 병렬로 HEAD 요청 수행
      final List<Future<int>> sizeFutures = manifest.assets.map((asset) async {
        try {
          final url = manifest.getFullUrl(asset.url);
          print('📏 크기 확인: ${asset.name} → $url');
          
          final response = await _dio.head(url);
          
          if (response.statusCode == 200) {
            final contentLength = response.headers.value('content-length');
            if (contentLength != null) {
              final size = int.parse(contentLength);
              print('   ✅ 크기: ${formatFileSize(size.toDouble())}');
              return size;
            } else {
              print('   ⚠️ Content-Length 헤더 없음');
              return 0;
            }
          } else {
            print('   ❌ HTTP 오류: ${response.statusCode}');
            return 0;
          }
        } catch (e) {
          print('   ❌ 크기 확인 실패: $e');
          return 0;
        }
      }).toList();
      
      // 모든 크기 정보 수집
      final sizes = await Future.wait(sizeFutures);
      totalSize = sizes.fold(0.0, (sum, size) => sum + size);
      
      print('📊 총 다운로드 크기: ${formatFileSize(totalSize)}');
    } catch (e) {
      print('❌ 전체 크기 계산 실패: $e');
      return -1;
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

  static String _getDioErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '연결 시간 초과 (5초)';
      case DioExceptionType.sendTimeout:
        return '요청 전송 시간 초과 (15초)';
      case DioExceptionType.receiveTimeout:
        return '응답 수신 시간 초과 (30초)';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          switch (statusCode) {
            case 404:
              return '파일을 찾을 수 없습니다 (404)';
            case 403:
              return '접근 권한이 없습니다 (403)';
            case 500:
              return '서버 내부 오류 (500)';
            default:
              return 'HTTP 오류 ($statusCode)';
          }
        }
        return 'HTTP 응답 오류';
      case DioExceptionType.cancel:
        return '요청이 취소되었습니다';
      case DioExceptionType.connectionError:
        return '네트워크 연결 실패';
      case DioExceptionType.badCertificate:
        return 'SSL 인증서 오류';
      case DioExceptionType.unknown:
        return '알 수 없는 네트워크 오류: ${error.message ?? ''}';
    }
  }

  // =================== 마스터 매니페스트 로컬 저장/로드 기능 ===================

  static const String _masterManifestFileName = 'master-manifest.json';

  /// 마스터 매니페스트를 앱 폴더에 저장
  static Future<void> saveMasterManifest(MasterManifest manifest) async {
    try {
      final appDocuments = await getApplicationDocumentsDirectory();
      final masterManifestFile = File('${appDocuments.path}/$_masterManifestFileName');
      
      final jsonString = json.encode(manifest.toJson());
      await masterManifestFile.writeAsString(jsonString);
      
      print('✅ 마스터 매니페스트 로컬 저장 완료: ${masterManifestFile.path}');
    } catch (e) {
      print('❌ 마스터 매니페스트 저장 실패: $e');
      throw Exception('마스터 매니페스트 저장 실패: $e');
    }
  }

  /// 로컬에 저장된 마스터 매니페스트 로드
  static Future<MasterManifest?> getLocalMasterManifest() async {
    try {
      final appDocuments = await getApplicationDocumentsDirectory();
      final masterManifestFile = File('${appDocuments.path}/$_masterManifestFileName');
      
      if (!await masterManifestFile.exists()) {
        print('📂 로컬 마스터 매니페스트 파일 없음: ${masterManifestFile.path}');
        return null;
      }
      
      final jsonString = await masterManifestFile.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final manifest = MasterManifest.fromJson(jsonData);
      
      print('✅ 로컬 마스터 매니페스트 로드 완료: ${manifest.filters.length}개 필터');
      return manifest;
    } catch (e) {
      print('❌ 로컬 마스터 매니페스트 로드 실패: $e');
      return null;
    }
  }

  /// 로컬 마스터 매니페스트가 존재하는지 확인
  static Future<bool> hasLocalMasterManifest() async {
    try {
      final appDocuments = await getApplicationDocumentsDirectory();
      final masterManifestFile = File('${appDocuments.path}/$_masterManifestFileName');
      return await masterManifestFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// 로컬 마스터 매니페스트 파일 삭제
  static Future<void> deleteLocalMasterManifest() async {
    try {
      final appDocuments = await getApplicationDocumentsDirectory();
      final masterManifestFile = File('${appDocuments.path}/$_masterManifestFileName');
      
      if (await masterManifestFile.exists()) {
        await masterManifestFile.delete();
        print('✅ 로컬 마스터 매니페스트 삭제 완료');
      }
    } catch (e) {
      print('❌ 로컬 마스터 매니페스트 삭제 실패: $e');
    }
  }

  /// 로컬 마스터 매니페스트의 수정 시간 확인
  static Future<DateTime?> getLocalMasterManifestModifiedTime() async {
    try {
      final appDocuments = await getApplicationDocumentsDirectory();
      final masterManifestFile = File('${appDocuments.path}/$_masterManifestFileName');
      
      if (!await masterManifestFile.exists()) {
        return null;
      }
      
      final stat = await masterManifestFile.stat();
      return stat.modified;
    } catch (e) {
      print('❌ 로컬 마스터 매니페스트 수정 시간 확인 실패: $e');
      return null;
    }
  }
}