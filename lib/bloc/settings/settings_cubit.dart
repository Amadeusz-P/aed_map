import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String languageCode;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.languageCode = '',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? languageCode,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  static const _themeKey = 'settings_theme_mode';
  static const _languageKey = 'settings_language_code';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeIndex = prefs.getInt(_themeKey);
    final themeMode = themeIndex != null ? ThemeMode.values[themeIndex] : ThemeMode.system;
    
    final languageCode = prefs.getString(_languageKey) ?? '';
    
    emit(state.copyWith(themeMode: themeMode, languageCode: languageCode));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
    emit(state.copyWith(languageCode: code));
  }
}
