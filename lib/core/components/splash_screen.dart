import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'brand_logo.dart';

class SplashScreenOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final Duration duration;

  const SplashScreenOverlay({
    super.key,
    required this.onDismiss,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<SplashScreenOverlay> createState() => _SplashScreenOverlayState();
}

class _SplashScreenOverlayState extends State<SplashScreenOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    _dismissTimer?.cancel();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _controller.value < 1.0) {
      _controller.value = 1.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF04060C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background subtle ambient radial glow
          Center(
            child: Container(
              width: 700,
              height: 700,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x221D1B4B),
                    Color(0x0C0E1626),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central Neural Network Synaptic Canvas
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = reduceMotion ? 1.0 : _controller.value;
                return CustomPaint(
                  painter: NeuralNetworkPainter(progress: progress),
                );
              },
            ),
          ),

          // Center Branding and AI Emblem
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Mind / Neural Orb Logo Emblem
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final val = reduceMotion ? 1.0 : _controller.value;
                      final pulseScale = 0.95 + 0.08 * math.sin(val * math.pi * 2);
                      return Transform.scale(
                        scale: pulseScale,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B65DB), Color(0xFF28D8D8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B65DB).withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: const Color(0xFF28D8D8).withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF080C16),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 36,
                                color: Color(0xFF9E8EFF),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Brand Logo
                  const BrandLogo(markSize: 32, fontSize: 24),

                  const SizedBox(height: 12),

                  // Purposeful subtitle with glowing cyan accent
                  const Text(
                    'AI-POWERED FULL-STACK STUDIO',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Plan · Build · Verify · Ship',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Skip button (accessible top-right)
          Positioned(
            top: 24,
            right: 24,
            child: OutlinedButton.icon(
              onPressed: _skip,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 13),
              label: const Text('Enter studio'),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0x14FFFFFF),
                foregroundColor: const Color(0xFFCAD5E8),
                side: const BorderSide(color: Color(0x288EA2C8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NeuralNetworkPainter extends CustomPainter {
  final double progress;

  NeuralNetworkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Node coordinates relative to center
    final nodeOffsets = [
      const Offset(-160, -90),
      const Offset(-90, -140),
      const Offset(90, -140),
      const Offset(160, -90),
      const Offset(170, 70),
      const Offset(100, 130),
      const Offset(-100, 130),
      const Offset(-170, 70),
      const Offset(-70, 0),
      const Offset(70, 0),
    ];

    final connections = [
      (0, 1), (1, 2), (2, 3), (3, 4), (4, 5),
      (5, 6), (6, 7), (7, 0), (0, 8), (8, 9),
      (9, 3), (8, 6), (9, 5), (1, 8), (2, 9),
    ];

    // Draw connecting lines with alpha fade and pulse
    final lineAlpha = (progress * 1.5).clamp(0.0, 1.0);
    for (final (a, b) in connections) {
      final p1 = Offset(cx + nodeOffsets[a].dx, cy + nodeOffsets[a].dy);
      final p2 = Offset(cx + nodeOffsets[b].dx, cy + nodeOffsets[b].dy);

      linePaint.color = Color.lerp(
        const Color(0xFF6E56CF),
        const Color(0xFF00E5FF),
        ((a + b) % 5) / 5.0,
      )!.withValues(alpha: 0.18 * lineAlpha);

      canvas.drawLine(p1, p2, linePaint);
    }

    // Draw synaptic nodes with pulsing glow
    for (int i = 0; i < nodeOffsets.length; i++) {
      final pos = Offset(cx + nodeOffsets[i].dx, cy + nodeOffsets[i].dy);
      final pulse = 0.5 + 0.5 * math.sin((progress * 4 * math.pi) + i);
      final nodeRadius = 2.5 + 1.5 * pulse;

      // Outer glow
      dotPaint.color = (i % 2 == 0 ? const Color(0xFF8B65DB) : const Color(0xFF00E5FF))
          .withValues(alpha: (0.35 * lineAlpha));
      canvas.drawCircle(pos, nodeRadius * 2.5, dotPaint);

      // Core dot
      dotPaint.color = Colors.white.withValues(alpha: (0.85 * lineAlpha));
      canvas.drawCircle(pos, nodeRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant NeuralNetworkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
