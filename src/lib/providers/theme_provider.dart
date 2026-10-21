import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:findr_application/theme/app_theme.dart';

// stores the user's selected theme settings.
class ThemePreferences {
  final FindrPalette palette;
  final bool darkMode;

  const ThemePreferences({
    this.palette = FindrPalette.blue,
    this.darkMode = false,
  });

  // creates a new copy while only changing the values given.
  ThemePreferences copyWith({
    FindrPalette? palette,
    bool? darkMode,
  }) {
    return ThemePreferences(
      palette: palette ?? this.palette,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

// keys used to save the theme settings on the device.
const String _paletteKey = 'findr_theme_palette';
const String _darkModeKey = 'findr_dark_mode';

// loads the saved theme settings from shared preferences.
// if nothing was saved before, the app uses the default blue light theme.
Future<ThemePreferences> loadThemePreferences() async {
  final SharedPreferences preferences =
      await SharedPreferences.getInstance();

  final String? savedPalette = preferences.getString(_paletteKey);

  final FindrPalette palette = FindrPalette.values.firstWhere(
    (option) => option.name == savedPalette,
    orElse: () => FindrPalette.blue,
  );

  return ThemePreferences(
    palette: palette,
    darkMode: preferences.getBool(_darkModeKey) ?? false,
  );
}

// provides the theme settings that were loaded when the app started.
final initialThemePreferencesProvider =
    Provider<ThemePreferences>((ref) {
  return const ThemePreferences();
});

// controls the current theme and lets the app update it.
final themeControllerProvider =
    NotifierProvider<ThemeController, ThemePreferences>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemePreferences> {
  @override
  ThemePreferences build() {
    return ref.watch(initialThemePreferencesProvider);
  }

  // changes the colour palette and saves the new choice.
  Future<void> setPalette(FindrPalette palette) async {
    // skips saving if the user picked the palette they already have.
    if (state.palette == palette) {
      return;
    }

    state = state.copyWith(palette: palette);

    final SharedPreferences preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(_paletteKey, palette.name);
  }

  // turns dark mode on or off and saves the setting.
  Future<void> setDarkMode(bool enabled) async {
    // skips saving if the setting did not actually change.
    if (state.darkMode == enabled) {
      return;
    }

    state = state.copyWith(darkMode: enabled);

    final SharedPreferences preferences =
        await SharedPreferences.getInstance();

    await preferences.setBool(_darkModeKey, enabled);
  }
}