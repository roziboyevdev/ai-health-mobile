import 'package:flutter/material.dart';

@immutable
class HealthColors extends ThemeExtension<HealthColors> {
  const HealthColors({
    required this.heart,
    required this.oxygen,
    required this.sleep,
    required this.activity,
    required this.stress,
  });

  final Color heart;
  final Color oxygen;
  final Color sleep;
  final Color activity;
  final Color stress;

  @override
  HealthColors copyWith({
    Color? heart,
    Color? oxygen,
    Color? sleep,
    Color? activity,
    Color? stress,
  }) {
    return HealthColors(
      heart: heart ?? this.heart,
      oxygen: oxygen ?? this.oxygen,
      sleep: sleep ?? this.sleep,
      activity: activity ?? this.activity,
      stress: stress ?? this.stress,
    );
  }

  @override
  HealthColors lerp(ThemeExtension<HealthColors>? other, double t) {
    if (other is! HealthColors) return this;
    return HealthColors(
      heart: Color.lerp(heart, other.heart, t)!,
      oxygen: Color.lerp(oxygen, other.oxygen, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      activity: Color.lerp(activity, other.activity, t)!,
      stress: Color.lerp(stress, other.stress, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const double cardRadius = 24;
  static const _materialBlue = Color(0xFF0B57D0);
  static const lightBackground = Color(0xFFF8FAFF);
  static const darkBackground = Color(0xFF101418);

  static ThemeData get lightTheme => _theme(
        ColorScheme.fromSeed(
          seedColor: _materialBlue,
          brightness: Brightness.light,
        ),
      );

  static ThemeData get darkTheme => _theme(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFA8C7FA),
          brightness: Brightness.dark,
        ),
      );

  static ThemeData get light => lightTheme;

  static ThemeData get dark => darkTheme;

  static ThemeData _theme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final background = isDark ? darkBackground : lightBackground;
    final cardColor = isDark ? const Color(0xFF1B2026) : Colors.white;
    final cardVariant = isDark ? const Color(0xFF20262D) : const Color(0xFFEFF4FF);
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      splashColor: scheme.primary.withValues(alpha: 0.12),
      highlightColor: scheme.primary.withValues(alpha: 0.06),
      hoverColor: scheme.primary.withValues(alpha: 0.04),
      colorScheme: scheme.copyWith(
        surface: background,
        surfaceContainer: isDark ? const Color(0xFF171C20) : const Color(0xFFF0F4FA),
        surfaceContainerHigh: cardVariant,
        surfaceContainerHighest: cardVariant,
      ),
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      extensions: const [
        HealthColors(
          heart: Color(0xFFE91E63),
          oxygen: Color(0xFF00ACC1),
          sleep: Color(0xFF536DFE),
          activity: Color(0xFF34A853),
          stress: Color(0xFF7E57C2),
        ),
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        selectedColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 74,
        backgroundColor: isDark ? const Color(0xFF171C20) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF252B31) : const Color(0xFFF3F6FB),
        prefixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outline.withValues(alpha: 0.75)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest;
        }),
      ),
    );
  }

  static WidgetStateProperty<Color?> overlayFor(Color color) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return color.withValues(alpha: 0.14);
      }
      if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
        return color.withValues(alpha: 0.08);
      }
      return null;
    });
  }
}
