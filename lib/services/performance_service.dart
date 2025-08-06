import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 얼굴 감지 성능 측정 및 모니터링 서비스
class PerformanceService {
  // 싱글톤 패턴
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // 성능 모니터링 활성화 여부 (최적화용)
  static bool isMonitoringEnabled = true;
  static const int _measurementInterval = 30; // 30프레임마다 측정

  // 성능 측정 변수들
  DateTime? _lastFrameTime;
  DateTime? _lastFaceDetectionStart;
  
  // FPS 계산
  double _currentFPS = 0.0;
  final List<double> _fpsHistory = [];
  static const int _maxFpsHistory = 30; // 30프레임 평균
  
  // 얼굴 감지 지연 시간 (밀리초)
  double _currentLatency = 0.0;
  final List<double> _latencyHistory = [];
  static const int _maxLatencyHistory = 30; // 30회 평균
  
  // 메모리 사용량 (MB)
  double _currentMemoryUsage = 0.0;
  
  // 성능 통계
  double _averageFPS = 0.0;
  double _minFPS = double.infinity;
  double _maxFPS = 0.0;
  
  double _averageLatency = 0.0;
  double _minLatency = double.infinity;
  double _maxLatency = 0.0;
  
  // 성능 경고 임계값
  static const double _fpsThreshold = 30.0;
  static const double _latencyThreshold = 100.0; // 밀리초
  
  // 성능 상태
  bool get isPerformanceGood => _currentFPS >= _fpsThreshold && _currentLatency <= _latencyThreshold;
  bool get isFPSGood => _currentFPS >= _fpsThreshold;
  bool get isLatencyGood => _currentLatency <= _latencyThreshold;

  // 프레임 카운터 (측정 간격 제어용)
  int _frameCounter = 0;
  
  // Getters
  double get currentFPS => _currentFPS;
  double get currentLatency => _currentLatency;
  double get currentMemoryUsage => _currentMemoryUsage;
  
  double get averageFPS => _averageFPS;
  double get minFPS => _minFPS == double.infinity ? 0.0 : _minFPS;
  double get maxFPS => _maxFPS;
  
  double get averageLatency => _averageLatency;
  double get minLatency => _minLatency == double.infinity ? 0.0 : _minLatency;
  double get maxLatency => _maxLatency;

  /// 새 프레임 시작 시 호출 - FPS 계산 (최적화: 간격별 측정)
  void startFrame() {
    _frameCounter++;
    
    // 최적화: 일정 간격마다만 측정
    if (!isMonitoringEnabled || (_frameCounter % _measurementInterval != 0)) {
      return;
    }
    
    final now = DateTime.now();
    
    if (_lastFrameTime != null) {
      // 프레임 간 시간 차이 계산 (밀리초) - 간격을 고려하여 계산
      final deltaTime = now.difference(_lastFrameTime!).inMicroseconds / 1000.0;
      
      if (deltaTime > 0) {
        // 실제 FPS 계산 (간격 고려)
        final fps = (1000.0 * _measurementInterval) / deltaTime;
        
        _currentFPS = fps;
        
        // FPS 히스토리 관리
        _fpsHistory.add(fps);
        if (_fpsHistory.length > _maxFpsHistory) {
          _fpsHistory.removeAt(0);
        }
        
        // 통계 업데이트
        _updateFPSStatistics(fps);
      }
    }
    
    _lastFrameTime = now;
  }
  
  /// 얼굴 감지 시작 시 호출 (최적화: 간격별 측정)
  void startFaceDetection() {
    // 최적화: 모니터링 비활성화 시 건너뛰기
    if (!isMonitoringEnabled) {
      return;
    }
    
    _lastFaceDetectionStart = DateTime.now();
  }
  
  /// 얼굴 감지 완료 시 호출 - 지연 시간 계산 (최적화: 간격별 측정)
  void endFaceDetection() {
    // 최적화: 모니터링 비활성화 시 건너뛰기
    if (!isMonitoringEnabled || _lastFaceDetectionStart == null) {
      return;
    }
    
    final now = DateTime.now();
    final latency = now.difference(_lastFaceDetectionStart!).inMilliseconds.toDouble();
    
    _currentLatency = latency;
    
    // 지연 시간 히스토리 관리
    _latencyHistory.add(latency);
    if (_latencyHistory.length > _maxLatencyHistory) {
      _latencyHistory.removeAt(0);
    }
    
    // 통계 업데이트
    _updateLatencyStatistics(latency);
  }
  
  /// 메모리 사용량 측정 (최적화: 1초마다 1회만 측정)
  void updateMemoryUsage() {
    // 최적화: 모니터링 비활성화 시 또는 매번 호출하지 않음
    if (!isMonitoringEnabled || (_frameCounter % (_measurementInterval * 2) != 0)) {
      return;
    }
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Flutter의 developer 패키지를 사용하여 메모리 사용량 측정
        developer.Timeline.startSync('memory_usage');
        final usage = ProcessInfo.currentRss / 1024 / 1024; // 바이트 → MB
        _currentMemoryUsage = usage;
        developer.Timeline.finishSync();
      }
    } catch (e) {
      // 메모리 측정 실패 시 0으로 설정
      _currentMemoryUsage = 0.0;
    }
  }
  
  /// FPS 통계 업데이트
  void _updateFPSStatistics(double fps) {
    // 평균 FPS 계산
    if (_fpsHistory.isNotEmpty) {
      _averageFPS = _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
    }
    
    // 최소/최대 FPS 업데이트
    if (fps < _minFPS) _minFPS = fps;
    if (fps > _maxFPS) _maxFPS = fps;
  }
  
  /// 지연 시간 통계 업데이트
  void _updateLatencyStatistics(double latency) {
    // 평균 지연 시간 계산
    if (_latencyHistory.isNotEmpty) {
      _averageLatency = _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;
    }
    
    // 최소/최대 지연 시간 업데이트
    if (latency < _minLatency) _minLatency = latency;
    if (latency > _maxLatency) _maxLatency = latency;
  }
  
  /// 성능 통계 리셋
  void resetStatistics() {
    _fpsHistory.clear();
    _latencyHistory.clear();
    
    _averageFPS = 0.0;
    _minFPS = double.infinity;
    _maxFPS = 0.0;
    
    _averageLatency = 0.0;
    _minLatency = double.infinity;
    _maxLatency = 0.0;
    
    _currentFPS = 0.0;
    _currentLatency = 0.0;
    _currentMemoryUsage = 0.0;
  }
  
  /// 디버그 정보 출력 (최적화: kDebugMode에서만 실행)
  void printPerformanceInfo() {
    if (!kDebugMode) return;
    
    print('=== 성능 정보 ===');
    print('현재 FPS: ${_currentFPS.toStringAsFixed(1)}');
    print('평균 FPS: ${_averageFPS.toStringAsFixed(1)} (최소: ${minFPS.toStringAsFixed(1)}, 최대: ${_maxFPS.toStringAsFixed(1)})');
    print('현재 지연시간: ${_currentLatency.toStringAsFixed(1)}ms');
    print('평균 지연시간: ${_averageLatency.toStringAsFixed(1)}ms (최소: ${minLatency.toStringAsFixed(1)}ms, 최대: ${_maxLatency.toStringAsFixed(1)}ms)');
    print('메모리 사용량: ${_currentMemoryUsage.toStringAsFixed(1)}MB');
    print('성능 상태: ${isPerformanceGood ? "양호" : "경고"}');
    if (!isPerformanceGood) {
      if (!isFPSGood) print('  - FPS 부족: ${_currentFPS.toStringAsFixed(1)} < $_fpsThreshold');
      if (!isLatencyGood) print('  - 지연시간 초과: ${_currentLatency.toStringAsFixed(1)}ms > $_latencyThreshold ms');
    }
  }
  
  /// 성능 경고 메시지 생성
  String? getPerformanceWarning() {
    if (isPerformanceGood) return null;
    
    final warnings = <String>[];
    if (!isFPSGood) {
      warnings.add('낮은 FPS: ${_currentFPS.toStringAsFixed(1)}');
    }
    if (!isLatencyGood) {
      warnings.add('높은 지연시간: ${_currentLatency.toStringAsFixed(0)}ms');
    }
    
    return warnings.join(', ');
  }
}