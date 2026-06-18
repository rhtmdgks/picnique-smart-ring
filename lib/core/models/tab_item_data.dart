import 'package:flutter/material.dart';

class TabItemData {
  final String title;
  final String iconSvgPath;
  final Widget screen;

  const TabItemData({
    required this.title,
    required this.iconSvgPath,
    required this.screen,
  });
}
