import 'package:flutter/material.dart';
import '../services/performance_service.dart';
import '../services/face_detection_service.dart';

/// 실시간 성능 정보를 화면에 표시하는 오버레이 위젯
class PerformanceOverlay extends StatefulWidget {
  final bool showDetailed;
  final EdgeInsetsGeometry? margin;

  const PerformanceOverlay({
    super.key,
    this.showDetailed = false,
    this.margin,
  });

  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  final PerformanceService _performanceService = PerformanceService();
  late Stream<int> _updateStream;

  @override
  void initState() {
    super.initState();
    // 실시간 업데이트를 위한 스트림 생성 (250ms마다 업데이트)
    _updateStream = Stream.periodic(const Duration(milliseconds: 250), (count) => count);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _updateStream,
      builder: (context, snapshot) {
        return _buildOverlay();
      },
    );
  }

  Widget _buildOverlay() {
    return Container(
      margin: widget.margin ?? const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _performanceService.isPerformanceGood 
              ? Colors.green 
              : Colors.red,
          width: 1,
        ),
      ),
      child: widget.showDetailed ? _buildDetailedView() : _buildCompactView(),
    );
  }

  /// 간단한 성능 표시 (FPS + 지연시간)
  Widget _buildCompactView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // FPS 표시
        _buildMetricItem(
          icon: Icons.speed,
          label: 'FPS',
          value: _performanceService.currentFPS.toStringAsFixed(1),
          isGood: _performanceService.isFPSGood,
          unit: '',
        ),
        
        const SizedBox(width: 16),
        
        // 지연 시간 표시
        _buildMetricItem(
          icon: Icons.timer,
          label: 'Delay',
          value: _performanceService.currentLatency.toStringAsFixed(0),
          isGood: _performanceService.isLatencyGood,
          unit: 'ms',
        ),
        
        const SizedBox(width: 16),
        
        // 랜드마크 상태 표시 (T2C.1)
        _buildLandmarkStatus(),
        
        // 경고 아이콘 (성능 이상 시)
        if (!_performanceService.isPerformanceGood) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.warning_amber,
            color: Colors.amber,
            size: 16,
          ),
        ],
      ],
    );
  }

  /// 상세한 성능 표시 (평균, 최소/최대 포함)
  Widget _buildDetailedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목
        Row(
          children: [
            Icon(
              Icons.analytics,
              color: _performanceService.isPerformanceGood ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '성능 모니터링',
              style: TextStyle(
                color: _performanceService.isPerformanceGood ? Colors.green : Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // FPS 정보
        _buildDetailedMetric(
          'FPS',
          current: _performanceService.currentFPS,
          average: _performanceService.averageFPS,
          min: _performanceService.minFPS,
          max: _performanceService.maxFPS,
          threshold: 30.0,
          unit: '',
          isHigherBetter: true,
        ),
        
        const SizedBox(height: 4),
        
        // 지연 시간 정보
        _buildDetailedMetric(
          '지연시간',
          current: _performanceService.currentLatency,
          average: _performanceService.averageLatency,
          min: _performanceService.minLatency,
          max: _performanceService.maxLatency,
          threshold: 100.0,
          unit: 'ms',
          isHigherBetter: false,
        ),
        
        // 메모리 사용량 (사용 가능한 경우)
        if (_performanceService.currentMemoryUsage > 0) ...[
          const SizedBox(height: 4),
          _buildSimpleMetric(
            '메모리',
            _performanceService.currentMemoryUsage,
            'MB',
            Colors.blue,
          ),
        ],
        
        // 성능 경고 메시지
        if (!_performanceService.isPerformanceGood) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _performanceService.getPerformanceWarning() ?? '성능 경고',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 기본 메트릭 표시 위젯
  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isGood,
    required String unit,
  }) {
    final color = isGood ? Colors.green : Colors.red;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          '$label: $value$unit',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 상세 메트릭 표시 위젯 (현재/평균/최소/최대)
  Widget _buildDetailedMetric(
    String label, {
    required double current,
    required double average,
    required double min,
    required double max,
    required double threshold,
    required String unit,
    required bool isHigherBetter,
  }) {
    final isGood = isHigherBetter 
        ? current >= threshold 
        : current <= threshold;
    final color = isGood ? Colors.green : Colors.red;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 값 (큰 글씨)
        Text(
          '$label: ${current.toStringAsFixed(isHigherBetter ? 1 : 0)}$unit',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // 통계 정보 (작은 글씨)
        Text(
          '평균 ${average.toStringAsFixed(isHigherBetter ? 1 : 0)}$unit, '
          '범위 ${min.toStringAsFixed(isHigherBetter ? 1 : 0)}-${max.toStringAsFixed(isHigherBetter ? 1 : 0)}$unit',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// 간단 메트릭 표시 위젯 (메모리 등)
  Widget _buildSimpleMetric(String label, double value, String unit, Color color) {
    return Text(
      '$label: ${value.toStringAsFixed(1)}$unit',
      style: TextStyle(
        color: color,
        fontSize: 11,
      ),
    );
  }

  /// 랜드마크 활성화 상태 표시 (T2C.1)
  Widget _buildLandmarkStatus() {
    final isLandmarksEnabled = FaceDetectionService.isInitialized;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.face,
          color: isLandmarksEnabled ? Colors.blue : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'LM',  // Landmarks 약자
          style: TextStyle(
            color: isLandmarksEnabled ? Colors.blue : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 성능 오버레이를 표시할 위치 enum
enum PerformanceOverlayPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// 위치 지정 가능한 성능 오버레이 위젯
class PositionedPerformanceOverlay extends StatelessWidget {
  final PerformanceOverlayPosition position;
  final bool showDetailed;

  const PositionedPerformanceOverlay({
    super.key,
    this.position = PerformanceOverlayPosition.topRight,
    this.showDetailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: position == PerformanceOverlayPosition.topLeft || 
            position == PerformanceOverlayPosition.topRight ? 16 : null,
      bottom: position == PerformanceOverlayPosition.bottomLeft || 
              position == PerformanceOverlayPosition.bottomRight ? 16 : null,
      left: position == PerformanceOverlayPosition.topLeft || 
            position == PerformanceOverlayPosition.bottomLeft ? 16 : null,
      right: position == PerformanceOverlayPosition.topRight || 
             position == PerformanceOverlayPosition.bottomRight ? 16 : null,
      child: PerformanceOverlay(
        showDetailed: showDetailed,
        margin: EdgeInsets.zero,
      ),
    );
  }
}