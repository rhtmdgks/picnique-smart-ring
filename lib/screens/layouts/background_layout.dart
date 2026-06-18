import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';

class BackgroundLayout extends StatelessWidget {
  final Widget child;
  const BackgroundLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: 0,
                height: 0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkPurple,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkPurple,
                      blurRadius: 200,
                      spreadRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
