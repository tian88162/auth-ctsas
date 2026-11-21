import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'services/wifi_monitor.dart';
import 'services/config_service.dart';
import 'models/portal_config.dart';

void main() {
  runApp(const CampusAuthApp());
}

class CampusAuthApp extends StatelessWidget {
  const CampusAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: '校园网自动认证',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}

/// 应用状态管理
class AppState extends ChangeNotifier {
  final WiFiMonitor _wifiMonitor = WiFiMonitor();
  final ConfigService _configService = ConfigService();
  
  PortalConfig _config = PortalConfig();
  LoginStatus _status = LoginStatus.idle;
  String _message = '等待中...';
  
  AppState() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    // 加载配置
    _config = await _configService.loadConfig();
    notifyListeners();
    
    // 设置WiFi监听回调
    _wifiMonitor.onStatusChanged = (status, message) {
      _status = status;
      _message = message;
      notifyListeners();
    };
    
    // 如果启用了自动登录，立即开始监听
    if (_config.autoLogin) {
      startMonitoring();
    }
  }
  
  // Getters
  PortalConfig get config => _config;
  LoginStatus get status => _status;
  String get message => _message;
  bool get isMonitoring => _wifiMonitor.currentStatus != LoginStatus.idle;
  
  /// 更新配置
  Future<void> updateConfig(PortalConfig newConfig) async {
    _config = newConfig;
    await _configService.saveConfig(_config);
    notifyListeners();
    
    // 如果启用了自动登录，重启监听
    if (_config.autoLogin) {
      startMonitoring();
    } else {
      stopMonitoring();
    }
  }
  
  /// 开始监听
  void startMonitoring() {
    _wifiMonitor.startMonitoring(_config);
    notifyListeners();
  }
  
  /// 停止监听
  void stopMonitoring() {
    _wifiMonitor.stopMonitoring();
    _status = LoginStatus.idle;
    _message = '监听已停止';
    notifyListeners();
  }
  
  /// 手动登录
  Future<LoginResult> login() async {
    final result = await _wifiMonitor.manualLogin(_config);
    return result;
  }
  
  @override
  void dispose() {
    _wifiMonitor.stopMonitoring();
    super.dispose();
  }
}
