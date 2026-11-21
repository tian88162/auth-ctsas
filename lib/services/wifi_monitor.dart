import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'portal_service.dart';
import '../models/portal_config.dart';

/// WiFi 监听和自动登录服务
class WiFiMonitor {
  final Logger _logger = Logger();
  final PortalService _portalService = PortalService();
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoLoginTimer;
  
  LoginStatus _currentStatus = LoginStatus.idle;
  String _lastMessage = '';
  
  // 回调函数
  Function(LoginStatus status, String message)? onStatusChanged;
  
  /// 开始监听WiFi状态
  void startMonitoring(PortalConfig config) {
    _logger.i('开始监听WiFi状态变化');
    
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results, config);
      },
    );
    
    // 立即检查一次当前网络状态
    _checkAndLogin(config);
    
    // 启动定时检查（每60秒检查一次是否需要重新认证）
    _autoLoginTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkAndLogin(config),
    );
  }
  
  /// 停止监听
  void stopMonitoring() {
    _logger.i('停止WiFi监听');
    _connectivitySubscription?.cancel();
    _autoLoginTimer?.cancel();
    _updateStatus(LoginStatus.idle, '监听已停止');
  }
  
  /// 处理网络状态变化
  void _handleConnectivityChange(List<ConnectivityResult> results, PortalConfig config) {
    _logger.i('网络状态变化: $results');
    
    if (results.contains(ConnectivityResult.wifi)) {
      _logger.i('已连接WiFi，准备自动登录');
      // WiFi连接后延迟3秒再登录（等待网络稳定）
      Future.delayed(const Duration(seconds: 3), () {
        _checkAndLogin(config);
      });
    } else {
      _updateStatus(LoginStatus.offline, 'WiFi未连接');
    }
  }
  
  /// 检查并执行登录
  Future<void> _checkAndLogin(PortalConfig config) async {
    if (!config.autoLogin || !config.isValid) {
      _logger.d('自动登录未启用或配置无效');
      return;
    }
    
    try {
      _updateStatus(LoginStatus.checking, '检测网络状态...');
      
      // 检查是否需要认证
      final needsAuth = await _portalService.needsAuthentication();
      
      if (!needsAuth) {
        _updateStatus(LoginStatus.success, '网络已连接');
        return;
      }
      
      // 需要认证，执行登录
      _updateStatus(LoginStatus.logging, '正在登录...');
      final result = await _portalService.login(config);
      
      if (result.success) {
        _updateStatus(LoginStatus.success, result.message);
      } else {
        _updateStatus(LoginStatus.failed, result.message);
      }
      
    } catch (e) {
      _logger.e('自动登录异常: $e');
      _updateStatus(LoginStatus.failed, '登录失败: $e');
    }
  }
  
  /// 手动触发登录
  Future<LoginResult> manualLogin(PortalConfig config) async {
    _updateStatus(LoginStatus.logging, '正在登录...');
    
    final result = await _portalService.login(config);
    
    if (result.success) {
      _updateStatus(LoginStatus.success, result.message);
    } else {
      _updateStatus(LoginStatus.failed, result.message);
    }
    
    return result;
  }
  
  /// 更新状态并触发回调
  void _updateStatus(LoginStatus status, String message) {
    _currentStatus = status;
    _lastMessage = message;
    onStatusChanged?.call(status, message);
  }
  
  /// 获取当前状态
  LoginStatus get currentStatus => _currentStatus;
  String get lastMessage => _lastMessage;
}
