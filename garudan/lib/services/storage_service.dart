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

  // ── Server Profiles ──────────────────────────────────────

  Future<List<ServerProfile>> getServerProfiles() async {
    final raw = _prefs.getString(AppConstants.keyServerProfiles);
    if (raw == null || raw.isEmpty) return [];
    try {
      return ServerProfile.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveServerProfiles(List<ServerProfile> profiles) async {
    await _prefs.setString(
      AppConstants.keyServerProfiles,
      ServerProfile.listToJson(profiles),
    );
  }

  Future<void> addServerProfile(ServerProfile profile) async {
    final profiles = await getServerProfiles();
    profiles.removeWhere((p) => p.id == profile.id);
    profiles.add(profile);
    await saveServerProfiles(profiles);
  }

  Future<void> removeServerProfile(String id) async {
    final profiles = await getServerProfiles();
    profiles.removeWhere((p) => p.id == id);
    await saveServerProfiles(profiles);
  }

  // ── Active Server ─────────────────────────────────────────

  String? getActiveServerId() => _prefs.getString(AppConstants.keyActiveServerId);
  Future<void> setActiveServerId(String id) =>
      _prefs.setString(AppConstants.keyActiveServerId, id);

  // ── Terminal Preferences ──────────────────────────────────

  double getTerminalFontSize() =>
      _prefs.getDouble(AppConstants.keyTerminalFontSize) ?? AppConstants.defaultFontSize;
  Future<void> setTerminalFontSize(double size) =>
      _prefs.setDouble(AppConstants.keyTerminalFontSize, size);

  String getTerminalFontFamily() =>
      _prefs.getString(AppConstants.keyTerminalFontFamily) ?? AppConstants.defaultFontFamily;
  Future<void> setTerminalFontFamily(String family) =>
      _prefs.setString(AppConstants.keyTerminalFontFamily, family);

  String getTerminalTheme() =>
      _prefs.getString(AppConstants.keyTerminalTheme) ?? 'amoled';
  Future<void> setTerminalTheme(String theme) =>
      _prefs.setString(AppConstants.keyTerminalTheme, theme);

  // ── Auth / Security ───────────────────────────────────────

  bool isPinEnabled() => _prefs.getBool(AppConstants.keyPinEnabled) ?? false;
  bool isBiometricEnabled() => _prefs.getBool(AppConstants.keyBiometricEnabled) ?? false;
  Future<void> setPinEnabled(bool v) => _prefs.setBool(AppConstants.keyPinEnabled, v);
  Future<void> setBiometricEnabled(bool v) => _prefs.setBool(AppConstants.keyBiometricEnabled, v);

  Future<String?> getPinHash() => _secure.read(key: AppConstants.keyPinHash);
  Future<void> setPinHash(String hash) =>
      _secure.write(key: AppConstants.keyPinHash, value: hash);
  Future<void> clearPin() => _secure.delete(key: AppConstants.keyPinHash);

  // ── First Launch ──────────────────────────────────────────

  bool isFirstLaunch() => _prefs.getBool(AppConstants.keyFirstLaunch) ?? true;
  Future<void> setFirstLaunchDone() => _prefs.setBool(AppConstants.keyFirstLaunch, false);

  // ── Command Snippets ──────────────────────────────────────

  Future<List<CommandSnippet>> getCommandSnippets() async {
    final raw = _prefs.getString(AppConstants.keyCommandSnippets);
    if (raw == null || raw.isEmpty) return _defaultSnippets;
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => CommandSnippet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultSnippets;
    }
  }

  Future<void> saveCommandSnippets(List<CommandSnippet> snippets) async {
    final raw = json.encode(snippets.map((s) => s.toJson()).toList());
    await _prefs.setString(AppConstants.keyCommandSnippets, raw);
  }

  static const List<CommandSnippet> _defaultSnippets = [
    CommandSnippet(id: 'htop',    label: 'htop',        command: 'htop'),
    CommandSnippet(id: 'dps',     label: 'docker ps',   command: 'docker ps'),
    CommandSnippet(id: 'dstats',  label: 'docker stats',command: 'docker stats --no-stream'),
    CommandSnippet(id: 'dfh',     label: 'disk usage',  command: 'df -h'),
    CommandSnippet(id: 'free',    label: 'memory',      command: 'free -h'),
    CommandSnippet(id: 'uptime',  label: 'uptime',      command: 'uptime'),
    CommandSnippet(id: 'last',    label: 'last logins', command: 'last -n 10'),
    CommandSnippet(id: 'netstat', label: 'open ports',  command: 'ss -tlnp'),
  ];
}
