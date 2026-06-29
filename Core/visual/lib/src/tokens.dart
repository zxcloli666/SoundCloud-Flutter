import 'package:flutter/widgets.dart';

/// Дизайн-токены легаси (тёмная палитра, стекло, тайминги). Значения 1:1 из
/// `index.css`. Акцент — НЕ здесь (он у каждого юзера свой, см. [ScPalette]).
abstract final class ScTokens {
  // Фоны
  static const bgRoot = Color(0xFF08080A); // #08080a
  static const bgPrimary = Color(0xF20A0A0C); // rgba(10,10,12,0.95)

  // Стеклянные tint'ы (поверх размытого фона)
  static const glassTint = Color(0x06FFFFFF); // 0.025
  static const glassTintHover = Color(0x0DFFFFFF); // 0.05
  static const glassTintActive = Color(0x17FFFFFF); // 0.09
  static const glassBorder = Color(0x0FFFFFFF); // 0.06
  static const glassBorderHi = Color(0x1FFFFFFF); // 0.12
  static const glassFeaturedTint = Color(0x05FFFFFF); // 0.02
  static const glassFeaturedBorder = Color(0x12FFFFFF); // 0.07
  static const npbGlassColor = Color(0x8C0F0F13); // rgba(15,15,19,0.55)

  // Текст
  static const textPrimary = Color(0xEBFFFFFF); // 0.92
  static const textSecondary = Color(0x8CFFFFFF); // 0.55
  static const textTertiary = Color(0x40FFFFFF); // 0.25

  // Радиусы
  static const rCard = 16.0; // rounded-2xl
  static const rButton = 12.0; // rounded-xl
  static const rNowBar = 28.0;
  static const rArt = 13.0;
  static const rHero = 40.0;
  static const rFocus = 8.0;

  // Тайминги
  static const dFast = Duration(milliseconds: 200);
  static const dGlass = Duration(milliseconds: 500);
  static const dSidebar = Duration(milliseconds: 300);

  // Кривые
  static const easeApple = Cubic(0.16, 1.0, 0.3, 1.0);
  static const easeLabel = Cubic(0.2, 0.8, 0.2, 1.0);

  // Перф-блюры (logical px ≈ CSS px); light = 0.
  static const blurBeautyNormal = 40.0;
  static const blurBeautyStrong = 60.0;
  static const blurBeautySoft = 28.0;
  static const blurMediumNormal = 18.0;
  static const blurMediumStrong = 26.0;
  static const blurMediumSoft = 16.0;

  // Light-mode замены стекла на плотный tint (без блюра)
  static const lightGlass = Color(0xD116161A); // rgba(22,22,26,0.82)
  static const lightGlassFeatured = Color(0xDB101014); // rgba(16,16,20,0.86)
  static const lightNpb = Color(0xEB0F0F13); // rgba(15,15,19,0.92)

  // Раскладка
  static const sidebarCollapsed = 56.0;
  static const sidebarExpanded = 196.0;
  static const titlebarHeight = 56.0;
}
