import 'package:flutter/material.dart';

/// Paperlogy static weights (pubspec.yaml). Use [fontWeight], not fontVariations.
abstract final class AppFontWeight {
  static const thin = FontWeight.w100;
  static const extraLight = FontWeight.w200;
  static const light = FontWeight.w300;
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semiBold = FontWeight.w600;
  static const bold = FontWeight.w700;
  static const extraBold = FontWeight.w800;
  static const black = FontWeight.w900;
}

@Deprecated('Use AppFontWeight with fontWeight')
abstract final class AppFontVariations {
  static const thin = AppFontWeight.thin;
  static const extraLight = AppFontWeight.extraLight;
  static const light = AppFontWeight.light;
  static const regular = AppFontWeight.regular;
  static const medium = AppFontWeight.medium;
  static const semiBold = AppFontWeight.semiBold;
  static const bold = AppFontWeight.bold;
  static const extraBold = AppFontWeight.extraBold;
  static const black = AppFontWeight.black;
}
