import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double markSize;
  final double fontSize;
  final bool isLight;

  const BrandLogo({
    super.key,
    this.markSize = 28,
    this.fontSize = 15,
    this.isLight = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLight ? AppColors.lightText : AppColors.darkText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand mark with 4 constellation nodes
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(markSize * 0.35),
            border: Border.all(
              color: const Color(0x406BCBFF),
              width: 1,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x8C6B5AEE),
                Color(0x210CB7E1),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D7566F0),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 4 constellation glowing nodes
              Positioned(
                top: markSize * 0.22,
                left: markSize * 0.25,
                child: _buildNode(),
              ),
              Positioned(
                top: markSize * 0.30,
                right: markSize * 0.22,
                child: _buildNode(),
              ),
              Positioned(
                bottom: markSize * 0.22,
                left: markSize * 0.22,
                child: _buildNode(),
              ),
              Positioned(
                bottom: markSize * 0.18,
                right: markSize * 0.25,
                child: _buildNode(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'Segoe UI',
                letterSpacing: -0.35,
                color: textColor,
              ),
              children: const [
                TextSpan(
                  text: 'AI App ',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: 'Builder',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildNode() {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFF8CE9FF),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF48D4F7),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
