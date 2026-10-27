import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NeuralOrb extends StatefulWidget {
  final bool isThinking;
  final double size;

  const NeuralOrb({super.key, this.isThinking = false, this.size = 116});

  @override
  State<NeuralOrb> createState() => _NeuralOrbState();
}

class _NeuralOrbState extends State<NeuralOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final pulse = widget.isThinking
              ? 0.85 + 0.15 * math.sin(t * 2 * math.pi * 2)
              : 0.95 + 0.05 * math.sin(t * 2 * math.pi);

          return SizedBox(
            width: s,
            height: s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer subtle glow
                Container(
                  width: s * 0.75,
                  height: s * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(
                          alpha: widget.isThinking ? 0.35 : 0.18,
                        ),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),

                // Core Sphere
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: s * 0.65,
                    height: s * 0.65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      gradient: RadialGradient(
                        center: const Alignment(-0.2, -0.3),
                        radius: 0.85,
                        colors: [
                          const Color(0xCCE0F7FF),
                          const Color(0x663A86EB),
                          const Color(0x335B3EC5),
                          Colors.transparent,
                        ],
                        stops: const [0.05, 0.28, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

                // Orbit 1: Elliptical ring
                Transform.rotate(
                  angle: -0.48 + (widget.isThinking ? t * 2 * math.pi : 0),
                  child: Transform.scale(
                    scaleY: 0.55,
                    child: Container(
                      width: s * 0.85,
                      height: s * 0.85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x4D6996EB),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),

                // Orbit 2: Counter-tilt elliptical ring
                Transform.rotate(
                  angle: 1.01 - (widget.isThinking ? t * 2 * math.pi * 1.3 : 0),
                  child: Transform.scale(
                    scaleY: 0.50,
                    child: Container(
                      width: s * 0.78,
                      height: s * 0.78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x3322CFE5),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // 6 Floating Core Nodes
                ...List.generate(6, (i) {
                  final angle =
                      (i * (math.pi / 3)) +
                      (t * 2 * math.pi * (widget.isThinking ? 1.5 : 0.4));
                  final r = s * 0.22 * (0.8 + 0.2 * math.sin(angle + i));
                  final dx = r * math.cos(angle);
                  final dy = r * math.sin(angle) * 0.8;

                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7EE5FF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF43D9F5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
