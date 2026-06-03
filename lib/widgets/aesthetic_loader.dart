import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AestheticLoader extends StatelessWidget {
  final double size;
  final Color? color;

  const AestheticLoader({
    super.key,
    this.size = 40.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? const Color(0xFF667EEA);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Emitting Ripple Ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: themeColor.withValues(alpha: 0.6),
                width: size * 0.05,
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scaleXY(
                begin: 0.3,
                end: 1.5,
                duration: 1200.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(
                duration: 1200.ms,
                curve: Curves.easeOutCubic,
              ),

          // 2. Secondary Ripple Ring (Delayed for continuous effect)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: themeColor.withValues(alpha: 0.4),
                width: size * 0.05,
              ),
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(),
                delay: 600.ms,
              )
              .scaleXY(
                begin: 0.3,
                end: 1.5,
                duration: 1200.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(
                duration: 1200.ms,
                curve: Curves.easeOutCubic,
              ),

          // 3. Lively Dynamic Spinning Ring
          SizedBox(
            width: size * 0.7,
            height: size * 0.7,
            child: CircularProgressIndicator(
              strokeWidth: size * 0.1,
              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              strokeCap: StrokeCap.round,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(
                duration: 1500.ms,
                curve: Curves.easeInOutBack,
              ),

          // 4. Beating Core Dot
          Container(
            width: size * 0.25,
            height: size * 0.25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeColor,
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.6),
                  blurRadius: size * 0.2,
                  spreadRadius: size * 0.05,
                ),
              ],
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scaleXY(
                begin: 0.6,
                end: 1.2,
                duration: 600.ms,
                curve: Curves.easeInOutCubic,
              )
              .then()
              .scaleXY(
                begin: 1.2,
                end: 0.6,
                duration: 600.ms,
                curve: Curves.easeInOutCubic,
              ),
        ],
      ),
    );
  }
}
