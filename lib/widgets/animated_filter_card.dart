import 'package:flutter/material.dart';

/// 케이팝 데몬 헌터스 테마의 애니메이션이 적용된 FilterCard 래퍼
class AnimatedFilterCard extends StatefulWidget {
  final Widget child;
  final bool isEnabled;
  
  const AnimatedFilterCard({
    super.key,
    required this.child,
    this.isEnabled = true,
  });

  @override
  State<AnimatedFilterCard> createState() => _AnimatedFilterCardState();
}

class _AnimatedFilterCardState extends State<AnimatedFilterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      _animationController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.isEnabled) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: widget.isEnabled
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E0FF).withValues(
                            alpha: 0.3 * _glowAnimation.value,
                          ),
                          blurRadius: 8 + (4 * _glowAnimation.value),
                          spreadRadius: _glowAnimation.value * 2,
                        ),
                      ],
                    )
                  : null,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}