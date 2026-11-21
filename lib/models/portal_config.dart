/// 认证配置模型
class PortalConfig {
  String username;
  String password;
  String portalUrl; // 认证门户地址
  bool autoLogin; // 是否开启自动登录
  bool notifyOnLogin; // 登录成功时通知
  
  PortalConfig({
    this.username = '',
    this.password = '',
    this.portalUrl = '',
    this.autoLogin = true,
    this.notifyOnLogin = true,
  });

  // 从JSON加载
  factory PortalConfig.fromJson(Map<String, dynamic> json) {
    return PortalConfig(
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      portalUrl: json['portalUrl'] ?? '',
      autoLogin: json['autoLogin'] ?? true,
      notifyOnLogin: json['notifyOnLogin'] ?? true,
    );
  }

  // 转为JSON
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'portalUrl': portalUrl,
      'autoLogin': autoLogin,
      'notifyOnLogin': notifyOnLogin,
    };
  }

  bool get isValid => username.isNotEmpty && password.isNotEmpty;
}

/// 登录状态
enum LoginStatus {
  idle,       // 空闲
  checking,   // 检测中
  logging,    // 登录中
  success,    // 成功
  failed,     // 失败
  offline,    // 离线（WiFi未连接）
}

/// 登录结果
class LoginResult {
  final bool success;
  final String message;
  final LoginStatus status;
  final DateTime timestamp;

  LoginResult({
    required this.success,
    required this.message,
    required this.status,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'LoginResult(success: $success, message: $message, status: $status)';
}
