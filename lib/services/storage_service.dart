import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/server_profile.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Initialize StorageService before use');
});

class StorageService {
  StorageService._(this._prefs, this._secure);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return StorageService._(prefs, secure);
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  // ── Server Profiles ───────────────────────────────────────────────────────
  Future<List<ServerProfile>> getServerProfiles() async {
    final raw = _prefs.getString(AppConstants.keyServerProfiles);
    if (raw == null || raw.isEmpty) return [];
    try { return ServerProfile.listFromJson(raw); } catch (_) { return []; }
  }

  Future<void> saveServerProfiles(List<ServerProfile> profiles) async =>
      _prefs.setString(AppConstants.keyServerProfiles, ServerProfile.listToJson(profiles));

  Future<void> addServerProfile(ServerProfile p) async {
    final list = await getServerProfiles();
    list.removeWhere((e) => e.id == p.id);
    list.add(p);
    await saveServerProfiles(list);
  }

  Future<void> removeServerProfile(String id) async {
    final list = await getServerProfiles();
    list.removeWhere((e) => e.id == id);
    await saveServerProfiles(list);
  }

  // ── Active Server ─────────────────────────────────────────────────────────
  String? getActiveServerId() => _prefs.getString(AppConstants.keyActiveServerId);
  Future<void> setActiveServerId(String id) => _prefs.setString(AppConstants.keyActiveServerId, id);

  // ── Theme ─────────────────────────────────────────────────────────────────
  bool isDarkMode() => _prefs.getBool(AppConstants.keyThemeMode) ?? true;
  Future<void> setDarkMode(bool v) => _prefs.setBool(AppConstants.keyThemeMode, v);

  // ── Terminal Prefs ────────────────────────────────────────────────────────
  double getTerminalFontSize() => _prefs.getDouble(AppConstants.keyTerminalFontSize) ?? AppConstants.defaultFontSize;
  Future<void> setTerminalFontSize(double s) => _prefs.setDouble(AppConstants.keyTerminalFontSize, s);
  String getTerminalTheme() => _prefs.getString(AppConstants.keyTerminalTheme) ?? 'amoled';
  Future<void> setTerminalTheme(String t) => _prefs.setString(AppConstants.keyTerminalTheme, t);

  // ── First Launch ──────────────────────────────────────────────────────────
  bool isFirstLaunch() => _prefs.getBool(AppConstants.keyFirstLaunch) ?? true;
  Future<void> setFirstLaunchDone() => _prefs.setBool(AppConstants.keyFirstLaunch, false);

  // ── Alert Settings ────────────────────────────────────────────────────────
  bool isAlertsEnabled() => _prefs.getBool(AppConstants.keyAlertsEnabled) ?? true;
  Future<void> setAlertsEnabled(bool v) => _prefs.setBool(AppConstants.keyAlertsEnabled, v);
  double getCpuThreshold() => _prefs.getDouble(AppConstants.keyAlertCpuThreshold) ?? AppConstants.defaultCpuThreshold;
  Future<void> setCpuThreshold(double v) => _prefs.setDouble(AppConstants.keyAlertCpuThreshold, v);
  double getDiskThreshold() => _prefs.getDouble(AppConstants.keyAlertDiskThreshold) ?? AppConstants.defaultDiskThreshold;
  Future<void> setDiskThreshold(double v) => _prefs.setDouble(AppConstants.keyAlertDiskThreshold, v);
  double getRamThreshold() => _prefs.getDouble(AppConstants.keyAlertRamThreshold) ?? AppConstants.defaultRamThreshold;
  Future<void> setRamThreshold(double v) => _prefs.setDouble(AppConstants.keyAlertRamThreshold, v);

  // ── SSH Keys (private keys stored encrypted) ──────────────────────────────
  Future<List<SshKeyPair>> getSshKeys() async {
    final raw = _prefs.getString(AppConstants.keySshKeys);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List).map((e) => SshKeyPair.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  Future<void> saveSshKeys(List<SshKeyPair> keys) async =>
      _prefs.setString(AppConstants.keySshKeys, json.encode(keys.map((k) => k.toJson()).toList()));

  Future<void> saveSshPrivateKey(String id, String privateKey) =>
      _secure.write(key: 'ssh_key_$id', value: privateKey);

  Future<String?> getSshPrivateKey(String id) => _secure.read(key: 'ssh_key_$id');

  Future<void> deleteSshKey(String id) async {
    final keys = await getSshKeys();
    keys.removeWhere((k) => k.id == id);
    await saveSshKeys(keys);
    await _secure.delete(key: 'ssh_key_$id');
  }

  // ── Command Snippets ──────────────────────────────────────────────────────
  Future<List<CommandSnippet>> getCommandSnippets() async {
    final raw = _prefs.getString(AppConstants.keyCommandSnippets);
    if (raw == null) return _defaultSnippets;
    try {
      return (json.decode(raw) as List).map((e) => CommandSnippet.fromJson(e)).toList();
    } catch (_) { return _defaultSnippets; }
  }

  Future<void> saveCommandSnippets(List<CommandSnippet> s) async =>
      _prefs.setString(AppConstants.keyCommandSnippets, json.encode(s.map((e) => e.toJson()).toList()));

  static const _defaultSnippets = [
    CommandSnippet(id: 'htop',    label: 'htop',         command: 'htop'),
    CommandSnippet(id: 'dps',     label: 'docker ps',    command: 'docker ps'),
    CommandSnippet(id: 'dfh',     label: 'disk usage',   command: 'df -h'),
    CommandSnippet(id: 'free',    label: 'memory',       command: 'free -h'),
    CommandSnippet(id: 'uptime',  label: 'uptime',       command: 'uptime'),
    CommandSnippet(id: 'netstat', label: 'open ports',   command: 'ss -tlnp'),
    CommandSnippet(id: 'last',    label: 'last logins',  command: 'last -n 10'),
    CommandSnippet(id: 'jctl',    label: 'journalctl',   command: 'journalctl -f'),
  ];

  String getTerminalFontFamily() =>
      _prefs.getString('terminal_font_family') ?? 'JetBrains Mono';

  Future<void> setTerminalFontFamily(String f) =>
      _prefs.setString('terminal_font_family', f);
}
