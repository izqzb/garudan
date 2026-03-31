class AppConstants {
  AppConstants._();
  static const String appName = 'Garudan';
  static const String appVersion = '1.1.0';
  static const String githubUrl = 'https://github.com/ajayaimannan/garudan';
  static const String githubServerUrl = 'https://github.com/ajayaimannan/garudan-server';
  static const String netdataDocsUrl = 'https://learn.netdata.cloud/docs/installing';
  static const String gotifyDocsUrl = 'https://gotify.net/docs/install';

  static const String keyServerProfiles = 'server_profiles_v2';
  static const String keyActiveServerId = 'active_server_id';
  static const String keyThemeMode = 'theme_mode';
  static const String keyTerminalTheme = 'terminal_theme';
  static const String keyTerminalFontSize = 'terminal_font_size';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyCommandSnippets = 'command_snippets';
  static const String keySshKeys = 'ssh_keys';
  static const String keyAlertCpuThreshold = 'alert_cpu_threshold';
  static const String keyAlertDiskThreshold = 'alert_disk_threshold';
  static const String keyAlertRamThreshold = 'alert_ram_threshold';
  static const String keyAlertsEnabled = 'alerts_enabled';

  static const double defaultFontSize = 14.0;
  static const double minFontSize = 8.0;
  static const double maxFontSize = 28.0;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration heartbeatInterval = Duration(seconds: 25);
  static const Duration reconnectBaseDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 10;
  static const int maxTerminalTabs = 10;

  static const double defaultCpuThreshold = 80.0;
  static const double defaultDiskThreshold = 75.0;
  static const double defaultRamThreshold = 85.0;
  static const Duration alertCheckInterval = Duration(minutes: 10);

  static const String pathTerminalWs = '/ws/terminal';
  static const String pathSystemStats = '/api/system/stats';
  static const String pathDockerContainers = '/api/docker/containers';
  static const String pathFiles = '/api/files';
  static const String pathProcesses = '/api/system/processes';
  static const String pathAuth = '/api/auth/token';
  static const String pathGotifyMessages = '/api/gotify/messages';
  static const String pathNetdata = '/api/netdata/stats';
}
