import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/portal_config.dart';

/// 配置存储服务
class ConfigService {
  static const String _configKey = 'portal_config';
  
  /// 保存配置
  Future<void> saveConfig(PortalConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(config.toJson());
    await prefs.setString(_configKey, jsonStr);
  }
  
  /// 加载配置
  Future<PortalConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_configKey);
    
    if (jsonStr == null || jsonStr.isEmpty) {
      return PortalConfig();
    }
    
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PortalConfig.fromJson(json);
    } catch (e) {
      return PortalConfig();
    }
  }
  
  /// 清除配置
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
  }
}
