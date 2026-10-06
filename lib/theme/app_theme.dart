import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AppColors {
  static const bg = Color(0xFFF1EEE6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFE9E5D9);
  static const ink = Color(0xFF23291F);
  static const inkSoft = Color(0xFF5B6156);
  static const forest = Color(0xFF2F4B3C);
  static const forestDeep = Color(0xFF1F3428);
  static const mustard = Color(0xFFC99A3E);
  static const clay = Color(0xFFA85C56);
  static const line = Color(0xFFDDD8C9);
  static const okBg = Color(0xFFE4EDE3);
}

class AppText {
  static TextStyle heading = GoogleFonts.fraunces(
    fontWeight: FontWeight.w600,
    color: AppColors.forestDeep,
  );

  static TextStyle body = GoogleFonts.inter(
    color: AppColors.ink,
    fontSize: 14,
  );

  static TextStyle bodySoft = GoogleFonts.inter(
    color: AppColors.inkSoft,
    fontSize: 12.5,
  );

  static TextStyle label = GoogleFonts.inter(
    color: AppColors.mustard,
    fontWeight: FontWeight.w700,
    fontSize: 11.5,
    letterSpacing: 0.3,
  );
}

ThemeData buildHouseheldTheme() {
  return ThemeData(
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
    ),
    useMaterial3: true,
  );
}
