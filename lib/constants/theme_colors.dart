import 'package:flutter/material.dart';

/// '케이팝 데몬 헌터스' 테마를 위한 컬러 팔레트
/// "Stage on, Demons out" 컨셉에 맞는 네온 색상 조합
class ThemeColors {
  // 기본 배경 색상들
  static const Color neoSeoulNight = Color(0xFF1A1229);    // 메인 배경색
  static const Color deepPurple = Color(0xFF3D2559);       // 카드, 앱바 배경
  static const Color darkGradientEnd = Color(0xFF2A1B3D);  // 그라데이션용
  
  // 액센트 및 강조 색상들
  static const Color neonBladeBlue = Color(0xFF00E0FF);    // 다운로드, 액션 버튼
  static const Color hunterPink = Color(0xFFE800FF);       // 경고, 실패 상태
  static const Color idolGold = Color(0xFFFFD700);         // 성공, 완료 상태
  
  // 텍스트 색상들
  static const Color white = Color(0xFFFFFFFF);            // 제목, 강조 텍스트
  static const Color lightLavender = Color(0xFFA095B3);    // 부제목, 설명 텍스트
  static const Color mutedText = Color(0xFF8A7CA8);        // 비활성 텍스트
  
  // 상태 색상들
  static const Color success = Color(0xFF00FF88);          // 성공 상태
  static const Color warning = Color(0xFFFFAA00);          // 경고 상태
  static const Color error = Color(0xFFFF4444);            // 에러 상태
  
  // 투명도별 색상 변형들
  static Color neonBladeBlueFaded = neonBladeBlue.withValues(alpha: 0.3);
  static Color hunterPinkFaded = hunterPink.withValues(alpha: 0.3);
  static Color deepPurpleFaded = deepPurple.withValues(alpha: 0.8);
  static Color blackOverlay = Colors.black.withValues(alpha: 0.6);
  
  // 그라데이션들
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepPurple, darkGradientEnd],
    stops: [0.0, 1.0],
  );
  
  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepPurple, neoSeoulNight],
    stops: [0.0, 1.0],
  );
  
  static LinearGradient neonGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      neonBladeBlue.withValues(alpha: 0.1),
      hunterPink.withValues(alpha: 0.1),
    ],
    stops: const [0.0, 1.0],
  );
  
  // 그림자 색상들
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: hunterPink.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> neonGlow = [
    BoxShadow(
      color: neonBladeBlue.withValues(alpha: 0.3),
      blurRadius: 12,
      spreadRadius: 2,
      offset: const Offset(0, 0),
    ),
  ];
  
  static List<BoxShadow> hunterPinkGlow = [
    BoxShadow(
      color: hunterPink.withValues(alpha: 0.3),
      blurRadius: 12,
      spreadRadius: 2,
      offset: const Offset(0, 0),
    ),
  ];
}