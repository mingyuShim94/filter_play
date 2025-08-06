import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResultScreen extends ConsumerWidget {
  final int score;
  final int totalBalloons;

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalBalloons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percentage = (score / totalBalloons * 100).round();
    final isExcellent = percentage >= 80;
    final isGood = percentage >= 60;

    return Scaffold(
      backgroundColor: isExcellent ? Colors.amber[50] : Colors.blue[50],
      appBar: AppBar(
        title: const Text('게임 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 결과 이모지
            Text(
              isExcellent ? '🎉' : isGood ? '😊' : '😔',
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 24),
            
            // 결과 메시지
            Text(
              isExcellent ? '완벽해요!' : isGood ? '잘했어요!' : '다시 도전해보세요!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isExcellent ? Colors.amber[700] : Colors.blue[700],
              ),
            ),
            const SizedBox(height: 32),
            
            // 점수 표시
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '터뜨린 풍선',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$score',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        ' / $totalBalloons',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$percentage% 성공!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            
            // 녹화 영상 미리보기 (Phase 5에서 구현)
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '📹 녹화 영상 미리보기 (Phase 5에서 구현)',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 액션 버튼들
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text('홈으로'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('다시하기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}