import 'package:flutter/material.dart';

// colour themes the user can choose from in settings.
enum FindrPalette {
  blue,
  lavender,
  mint,
  sunset,
}

// adds names and descriptions for each colour theme.
extension FindrPaletteDetails on FindrPalette {
  String get label => switch (this) {
        FindrPalette.blue => 'Blue',
        FindrPalette.lavender => 'Lavender',
        FindrPalette.mint => 'Mint',
        FindrPalette.sunset => 'Sunset',
      };

  String get description => switch (this) {
        FindrPalette.blue => 'The original Findr look',
        FindrPalette.lavender => 'Soft violet and periwinkle',
        FindrPalette.mint => 'Fresh teal and seafoam',
        FindrPalette.sunset => 'Warm coral and peach',
      };
}

// stores the custom colours used across the app.
@immutable
class FindrColors extends ThemeExtension<FindrColors> {
  final Color primary;
  final Color primaryStrong;
  final Color accent;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceSoft;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color muted;
  final Color navUnselected;
  final Color logoLetters;
  final Color logoPin;
  final Color illustrationTint;
  final Color illustrationOverlay;

  const FindrColors({
    required this.primary,
    required this.primaryStrong,
    required this.accent,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.muted,
    required this.navUnselected,
    required this.logoLetters,
    required this.logoPin,
    required this.illustrationTint,
    required this.illustrationOverlay,
  });

  // gets the current findr colours from the app theme.
  static FindrColors of(BuildContext context) {
    return Theme.of(context).extension<FindrColors>() ??
        FindrTheme._lightColors(FindrPalette.blue);
  }

  // creates a copy while only changing the colours given.
  @override
  FindrColors copyWith({
    Color? primary,
    Color? primaryStrong,
    Color? accent,
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? surfaceSoft,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? muted,
    Color? navUnselected,
    Color? logoLetters,
    Color? logoPin,
    Color? illustrationTint,
    Color? illustrationOverlay,
  }) {
    return FindrColors(
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      muted: muted ?? this.muted,
      navUnselected: navUnselected ?? this.navUnselected,
      logoLetters: logoLetters ?? this.logoLetters,
      logoPin: logoPin ?? this.logoPin,
      illustrationTint: illustrationTint ?? this.illustrationTint,
      illustrationOverlay:
          illustrationOverlay ?? this.illustrationOverlay,
    );
  }

  // smoothly changes between theme colours during animations.
  @override
  FindrColors lerp(
    covariant FindrColors? other,
    double t,
  ) {
    if (other == null) {
      return this;
    }

    return FindrColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong:
          Color.lerp(primaryStrong, other.primaryStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background:
          Color.lerp(background, other.background, t)!,
      backgroundAlt:
          Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft:
          Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary:
          Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      navUnselected:
          Color.lerp(navUnselected, other.navUnselected, t)!,
      logoLetters:
          Color.lerp(logoLetters, other.logoLetters, t)!,
      logoPin: Color.lerp(logoPin, other.logoPin, t)!,
      illustrationTint: Color.lerp(
        illustrationTint,
        other.illustrationTint,
        t,
      )!,
      illustrationOverlay: Color.lerp(
        illustrationOverlay,
        other.illustrationOverlay,
        t,
      )!,
    );
  }
}

// builds the light or dark theme used by the whole app.
class FindrTheme {
  const FindrTheme._();

  static ThemeData build(
    FindrPalette palette, {
    required Brightness brightness,
  }) {
    final bool dark =
        brightness == Brightness.dark;

    final FindrColors colors = dark
        ? _darkColors(palette)
        : _lightColors(palette);

    // creates the main material colour scheme from the selected palette.
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: Colors.white,
          secondary: colors.accent,
          surface: colors.surface,
          onSurface: colors.textPrimary,
          outline: colors.border,
        );

    // base theme used before adding the custom widget styles below.
    final ThemeData base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      cardColor: colors.surface,
      dividerColor: colors.border,
      fontFamily: 'Roboto',
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[
        colors,
      ],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(
          alpha: dark ? 0.48 : 0.16,
        ),
        elevation: dark ? 18 : 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colors.border,
          ),
        ),
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSoft,
        hintStyle: TextStyle(
          color: colors.muted,
        ),
        prefixIconColor: colors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.25,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE0415F),
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE0415F),
            width: 1.35,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor:
            WidgetStateProperty.resolveWith(
          (states) {
            return states.contains(
              WidgetState.selected,
            )
                ? colors.primary
                : colors.navUnselected;
          },
        ),
        trackColor:
            WidgetStateProperty.resolveWith(
          (states) {
            return states.contains(
              WidgetState.selected,
            )
                ? colors.primary.withValues(
                    alpha: 0.34,
                  )
                : colors.border;
          },
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark
            ? colors.surfaceSoft
            : colors.primaryStrong,
        contentTextStyle: const TextStyle(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // returns the colours for the selected light theme.
  static FindrColors _lightColors(
    FindrPalette palette,
  ) {
    return switch (palette) {
      FindrPalette.blue => const FindrColors(
          primary: Color(0xFF1976D2),
          primaryStrong: Color(0xFF105FAE),
          accent: Color(0xFF4BA3FF),
          background: Color(0xFFF4F8FF),
          backgroundAlt: Color(0xFFE8F0FE),
          surface: Color(0xFFFFFFFF),
          surfaceSoft: Color(0xFFEDF5FF),
          border: Color(0xFFDCE7F6),
          textPrimary: Color(0xFF14213D),
          textSecondary: Color(0xFF7284AA),
          muted: Color(0xFF9AB4DA),
          navUnselected: Color(0xFF9AA7C2),
          logoLetters: Color(0xFF001F5B),
          logoPin: Color(0xFF00A8E8),
          illustrationTint: Color(0xFF4B9DF4),
          illustrationOverlay: Color(0x00000000),
        ),

      FindrPalette.lavender => const FindrColors(
          primary: Color(0xFF7656D6),
          primaryStrong: Color(0xFF583ABB),
          accent: Color(0xFFA48BFF),
          background: Color(0xFFF8F6FF),
          backgroundAlt: Color(0xFFF0ECFF),
          surface: Color(0xFFFFFFFF),
          surfaceSoft: Color(0xFFEEE9FF),
          border: Color(0xFFE1D9F7),
          textPrimary: Color(0xFF271D43),
          textSecondary: Color(0xFF756A95),
          muted: Color(0xFFA79CC4),
          navUnselected: Color(0xFF9B93B4),
          logoLetters: Color(0xFF2B195B),
          logoPin: Color(0xFF8F70F0),
          illustrationTint: Color(0xFF8D73E8),
          illustrationOverlay: Color(0x0F7C5CFC),
        ),

      FindrPalette.mint => const FindrColors(
          primary: Color(0xFF0F8274),
          primaryStrong: Color(0xFF07695E),
          accent: Color(0xFF52CDB8),
          background: Color(0xFFF2FBF9),
          backgroundAlt: Color(0xFFE4F6F2),
          surface: Color(0xFFFFFFFF),
          surfaceSoft: Color(0xFFDFF4EF),
          border: Color(0xFFCFE8E2),
          textPrimary: Color(0xFF173934),
          textSecondary: Color(0xFF658C85),
          muted: Color(0xFF8FB5AE),
          navUnselected: Color(0xFF8DA8A3),
          logoLetters: Color(0xFF123E37),
          logoPin: Color(0xFF21B7A1),
          illustrationTint: Color(0xFF39B5A3),
          illustrationOverlay: Color(0x10149B8A),
        ),

      FindrPalette.sunset => const FindrColors(
          primary: Color(0xFFC84C56),
          primaryStrong: Color(0xFFA93645),
          accent: Color(0xFFFF9A72),
          background: Color(0xFFFFF7F5),
          backgroundAlt: Color(0xFFFFECE7),
          surface: Color(0xFFFFFFFF),
          surfaceSoft: Color(0xFFFFE5DF),
          border: Color(0xFFF2D7D1),
          textPrimary: Color(0xFF432127),
          textSecondary: Color(0xFF956D72),
          muted: Color(0xFFBE9BA0),
          navUnselected: Color(0xFFB1979B),
          logoLetters: Color(0xFF5B2430),
          logoPin: Color(0xFFF07972),
          illustrationTint: Color(0xFFF27A72),
          illustrationOverlay: Color(0x10EF6A6A),
        ),
    };
  }

  // creates dark mode colours using the selected palette.
  static FindrColors _darkColors(
    FindrPalette palette,
  ) {
    final FindrColors light =
        _lightColors(palette);

    final Color darkPrimary =
        switch (palette) {
      FindrPalette.blue =>
        const Color(0xFF1976D2),
      FindrPalette.lavender =>
        const Color(0xFF7656D6),
      FindrPalette.mint =>
        const Color(0xFF0F8274),
      FindrPalette.sunset =>
        const Color(0xFFC84C56),
    };

    // keeps the palette identity but swaps the main surfaces for dark ones.
    return light.copyWith(
      primary: darkPrimary,
      primaryStrong: Color.lerp(
        darkPrimary,
        Colors.black,
        0.18,
      ),
      accent: Color.lerp(
        light.accent,
        Colors.white,
        0.12,
      ),
      background:
          const Color(0xFF0B1524),
      backgroundAlt:
          const Color(0xFF101D31),
      surface:
          const Color(0xFF142138),
      surfaceSoft:
          const Color(0xFF1D2D49),
      border:
          const Color(0xFF3A4963),
      textPrimary:
          const Color(0xFFF3F6FC),
      textSecondary:
          const Color(0xFFC7D2E3),
      muted:
          const Color(0xFFA4B2C7),
      navUnselected:
          const Color(0xFF9EACC0),

      logoLetters: switch (palette) {
        FindrPalette.blue =>
          const Color(0xFFEAF3FF),
        FindrPalette.lavender =>
          const Color(0xFFF1ECFF),
        FindrPalette.mint =>
          const Color(0xFFE7FFFA),
        FindrPalette.sunset =>
          const Color(0xFFFFF0ED),
      },

      logoPin: switch (palette) {
        FindrPalette.blue =>
          const Color(0xFF46A4F2),
        FindrPalette.lavender =>
          const Color(0xFFA58BFF),
        FindrPalette.mint =>
          const Color(0xFF45CDB6),
        FindrPalette.sunset =>
          const Color(0xFFFF8A84),
      },

      illustrationTint: darkPrimary,
      illustrationOverlay:
          Colors.transparent,
    );
  }
}