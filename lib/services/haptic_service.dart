import 'package:flutter/services.dart';

/// Centralised haptic feedback — mirrors the feel of your old Garuda app.
class HapticService {
  HapticService._();

  /// Subtle — key taps, list selections
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium — toolbar actions, toggles
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Heavy — destructive actions, close session
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Double-tap pattern — successful SSH connection
  static Future<void> connected() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  }

  /// Triple buzz — error / failed connection
  static Future<void> error() async {
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      if (i < 2) await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  /// Single click — key press in keyboard toolbar
  static Future<void> keyClick() => HapticFeedback.selectionClick();

  /// Success — copy confirmed, save confirmed
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }
}
