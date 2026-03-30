import 'package:flutter/material.dart';

import '../branding.dart';
import '../theme/app_theme.dart';

/// Logo app ([kAppLogoAsset]), con fallback se l'asset manca.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.showShadow = true,
  });

  final double size;
  final bool showShadow;

  static const assetPath = kAppLogoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              gradient: AppColors.gradientRedDeep,
            ),
            child: Icon(
              Icons.shield,
              size: size * 0.45,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
