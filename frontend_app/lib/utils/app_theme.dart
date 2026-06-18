import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary  = Color(0xFF185FA5);
  static const success  = Color(0xFF0F6E56);
  static const warning  = Color(0xFFBA7517);
  static const danger   = Color(0xFFA32D2D);

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    textTheme: GoogleFonts.interTextTheme(),
    scaffoldBackgroundColor: const Color(0xFFF8F8F8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
      iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: Color(0xFF888780),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1A1A1A),
      selectedItemColor: Color(0xFF64B5F6),
      unselectedItemColor: Color(0xFF9E9E9E),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF64B5F6),
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
  );
}

class AppColors {
  static const Map<String, Color> category = {
    'Food & Dining': Color(0xFFE24B4A),
    'Transport':     Color(0xFF378ADD),
    'Grocery':       Color(0xFF639922),
    'Bills':         Color(0xFFBA7517),
    'Health':        Color(0xFFD4537E),
    'Shopping':      Color(0xFF7F77DD),
    'Transfer':      Color(0xFF1D9E75),
    'Other':         Color(0xFF888780),
  };
  static const Map<String, Color> categoryBg = {
    'Food & Dining': Color(0xFFFCEBEB),
    'Transport':     Color(0xFFE6F1FB),
    'Grocery':       Color(0xFFEAF3DE),
    'Bills':         Color(0xFFFAEEDA),
    'Health':        Color(0xFFFBEAF0),
    'Shopping':      Color(0xFFEEEDFE),
    'Transfer':      Color(0xFFE1F5EE),
    'Other':         Color(0xFFF1EFE8),
  };
  static const Map<String, Color> upiApp = {
    'GPay':      Color(0xFF185FA5),
    'PhonePe':   Color(0xFF534AB7),
    'Paytm':     Color(0xFF854F0B),
    'BHIM':      Color(0xFF0F6E56),
    'AmazonPay': Color(0xFF993C1D),
    'SMS':       Color(0xFF673AB7),
    'Other':     Color(0xFF888780),
  };
}

class AppIcons {
  static const Map<String, IconData> category = {
    'Food & Dining': Icons.restaurant_outlined,
    'Transport':     Icons.directions_car_outlined,
    'Grocery':       Icons.shopping_cart_outlined,
    'Bills':         Icons.bolt_outlined,
    'Health':        Icons.favorite_outline,
    'Shopping':      Icons.shopping_bag_outlined,
    'Transfer':      Icons.swap_horiz,
    'Other':         Icons.more_horiz,
  };
}

const kCategories = ['Food & Dining','Transport','Grocery','Bills','Health','Shopping','Transfer','Other'];
const kUpiApps    = ['GPay','PhonePe','Paytm','BHIM','AmazonPay','SMS','Other'];
const kBudgets    = {
  'Food & Dining': 3000.0,
  'Transport':     1500.0,
  'Grocery':       2500.0,
  'Bills':         2000.0,
  'Health':        1000.0,
  'Shopping':      2000.0,
};
