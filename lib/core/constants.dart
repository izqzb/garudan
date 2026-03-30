/// Garudan — App-wide constants
library;

class AppConstants {
  AppConstants._();

  static const String appName = 'Garudan';
  static const String appVersion = '1.0.0';
  static const String githubUrl = 'https://github.com/your-username/garudan';

  // Storage keys
  static const String keyServerProfiles = 'server_profiles';
  static const String keyActiveServerId = 'active_server_id';
  static const String keyThemeMode = 'theme_mode';
  static const String keyTerminalTheme = 'terminal_theme';
  static const String keyTerminalFontSize = 'terminal_font_size';
  static const String keyTerminalFontFamily = 'terminal_font_family';
  static const String keyPinEnabled = 'pin_enabled';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyPinHash = 'pin_hash';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyCommandSnippets = 'command_snippets';

  // Terminal defaults
  static const double defaultFontSize = 14.0;
  static const double minFontSize = 8.0;
  static const double maxFontSize = 28.0;
  static const String defaultFontFamily = 'JetBrains Mono';

  // Connection timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration heartbeatInterval = Duration(seconds: 25);
  static const Duration reconnectBaseDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 10;
  static const int maxTerminalTabs = 10;

  // API paths
  static const String pathTerminalWs = '/ws/terminal';
  static const String pathSystemStats = '/api/system/stats';
  static const String pathDockerContainers = '/api/docker/containers';
  static const String pathDockerAction = '/api/docker/containers/{id}/{action}';
  static const String pathFiles = '/api/files';
  static const String pathProcesses = '/api/system/processes';
  static const String pathAuth = '/api/auth/token';
  static const String pathGotifyMessages = '/api/gotify/messages';
  static const String pathPortForward = '/api/portforward';
}
