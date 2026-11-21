import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';
import '../models/portal_config.dart';

/// Portal 认证服务 - 支持多种校园网协议
class PortalService {
  final Logger _logger = Logger();
  
  /// 检测是否需要认证（Captive Portal 检测）
  Future<bool> needsAuthentication() async {
    try {
      // 尝试访问公网检测地址（204响应=已联网，302/200=需要认证）
      final response = await http.get(
        Uri.parse('http://connectivitycheck.gstatic.com/generate_204'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 5));
      
      // 204 = 已联网不需认证
      if (response.statusCode == 204) {
        return false;
      }
      
      // 302/200 = 被劫持到认证页面
      if (response.statusCode == 302 || response.statusCode == 200) {
        _logger.i('检测到需要Portal认证');
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.w('网络检测失败: $e');
      return false;
    }
  }

  /// 执行登录 - 自动适配VBRAS/锐捷/深澜等协议
  Future<LoginResult> login(PortalConfig config) async {
    if (!config.isValid) {
      return LoginResult(
        success: false,
        message: '配置无效：请填写用户名和密码',
        status: LoginStatus.failed,
      );
    }

    try {
      _logger.i('开始登录: ${config.username}');
      
      // 步骤1: 访问认证页面，获取重定向的Portal URL
      final portalUrl = await _detectPortalUrl(config.portalUrl);
      if (portalUrl == null) {
        return LoginResult(
          success: false,
          message: '无法检测到认证门户',
          status: LoginStatus.failed,
        );
      }

      _logger.i('检测到Portal: $portalUrl');

      // 步骤2: 分析Portal类型并执行登录
      final result = await _executeLogin(portalUrl, config);
      return result;
      
    } catch (e) {
      _logger.e('登录异常: $e');
      return LoginResult(
        success: false,
        message: '登录失败: $e',
        status: LoginStatus.failed,
      );
    }
  }

  /// 检测Portal重定向URL（从302跳转中提取真实门户地址）
  Future<String?> _detectPortalUrl(String? customUrl) async {
    try {
      // 如果用户配置了自定义门户地址，直接使用
      if (customUrl != null && customUrl.isNotEmpty) {
        return customUrl;
      }

      // 否则通过访问公网地址获取302跳转
      final client = http.Client();
      final request = http.Request('GET', Uri.parse('http://www.msftconnecttest.com/redirect'));
      request.followRedirects = false;
      
      final response = await client.send(request).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 302 || response.statusCode == 301) {
        final location = response.headers['location'];
        if (location != null && location.contains('portal')) {
          return location;
        }
      }
      
      // 如果没拿到跳转，读取响应body可能包含跳转脚本
      final bodyBytes = await response.stream.toBytes();
      final body = utf8.decode(bodyBytes);
      
      // 尝试从HTML中提取portal URL
      final portalUrl = _extractPortalFromHtml(body);
      if (portalUrl != null) {
        return portalUrl;
      }

      return null;
    } catch (e) {
      _logger.w('检测Portal URL失败: $e');
      return null;
    }
  }

  /// 从HTML中提取Portal URL
  String? _extractPortalFromHtml(String html) {
    try {
      final doc = html_parser.parse(html);
      
      // 查找iframe/meta标签中的跳转地址
      final metaRefresh = doc.querySelector('meta[http-equiv="refresh"]');
      if (metaRefresh != null) {
        final content = metaRefresh.attributes['content'] ?? '';
        final urlMatch = RegExp(r'url=([^"]+)').firstMatch(content);
        if (urlMatch != null) {
          return urlMatch.group(1);
        }
      }
      
      // 查找form action中的portal地址
      final form = doc.querySelector('form[action*="portal"]');
      if (form != null) {
        return form.attributes['action'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 执行实际的登录请求
  Future<LoginResult> _executeLogin(String portalUrl, PortalConfig config) async {
    try {
      final uri = Uri.parse(portalUrl);
      
      // 从URL查询参数中提取认证所需参数
      final queryParams = uri.queryParameters;
      final userIp = queryParams['wlanuserip'] ?? queryParams['userip'] ?? '';
      final acName = queryParams['wlanacname'] ?? queryParams['ac_name'] ?? '';
      final mac = queryParams['mac'] ?? '';
      
      _logger.d('认证参数: userIp=$userIp, acName=$acName, mac=$mac');

      // 尝试多种常见Portal登录协议
      
      // 1. VBRAS/锐捷 Portal（POST到portal.do）
      if (portalUrl.contains('portal.do') || portalUrl.contains('eportal')) {
        return await _loginVBRAS(uri, config, userIp, acName, mac);
      }
      
      // 2. 深澜Portal（POST到cgi-bin/srun_portal）
      if (portalUrl.contains('srun_portal') || portalUrl.contains('srun')) {
        return await _loginSRun(uri, config, userIp, acName);
      }
      
      // 3. Dr.COM（POST到login）
      if (portalUrl.contains('drcom') || portalUrl.contains('0.0.0.0')) {
        return await _loginDrCOM(uri, config, userIp, mac);
      }

      // 通用方法：访问portal页面并解析表单
      return await _loginGeneric(portalUrl, config);
      
    } catch (e) {
      _logger.e('登录执行失败: $e');
      return LoginResult(
        success: false,
        message: '登录失败: $e',
        status: LoginStatus.failed,
      );
    }
  }

  /// VBRAS/锐捷 Portal 登录
  Future<LoginResult> _loginVBRAS(Uri portalUri, PortalConfig config, 
      String userIp, String acName, String mac) async {
    try {
      // 构造登录POST参数（常见格式）
      final postData = {
        'DDDDD': config.username,  // 用户名
        'upass': config.password,   // 密码
        'R1': '0',
        'R2': '',
        'R3': '0',
        'R6': '0',
        'para': '00',
        '0MKKey': '123456',
        'v46s': '0',
      };

      final response = await http.post(
        portalUri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
        },
        body: postData,
      ).timeout(const Duration(seconds: 15));

      _logger.d('VBRAS响应状态: ${response.statusCode}');
      
      final body = response.body;
      
      // 判断登录结果（多种成功标识）
      if (body.contains('登录成功') || 
          body.contains('认证成功') ||
          body.contains('login success') ||
          response.statusCode == 204) {
        return LoginResult(
          success: true,
          message: '登录成功',
          status: LoginStatus.success,
        );
      }
      
      // 提取失败原因
      String failMsg = '登录失败';
      if (body.contains('密码错误')) {
        failMsg = '用户名或密码错误';
      } else if (body.contains('欠费') || body.contains('余额不足')) {
        failMsg = '账户欠费';
      } else if (body.contains('已在线') || body.contains('重复登录')) {
        failMsg = '该账号已在其他设备登录';
      }
      
      return LoginResult(
        success: false,
        message: failMsg,
        status: LoginStatus.failed,
      );
      
    } catch (e) {
      _logger.e('VBRAS登录异常: $e');
      return LoginResult(
        success: false,
        message: '网络请求失败',
        status: LoginStatus.failed,
      );
    }
  }

  /// 深澜 SRUN Portal 登录
  Future<LoginResult> _loginSRun(Uri portalUri, PortalConfig config,
      String userIp, String acName) async {
    try {
      // 深澜协议需要先获取challenge
      final infoData = {
        'username': config.username,
        'ip': userIp,
        'ac_id': '1',
      };
      
      final challengeUrl = Uri.parse('${portalUri.origin}/cgi-bin/get_challenge');
      final challengeResp = await http.get(
        challengeUrl.replace(queryParameters: infoData),
      ).timeout(const Duration(seconds: 10));
      
      if (challengeResp.statusCode != 200) {
        return LoginResult(
          success: false,
          message: '获取challenge失败',
          status: LoginStatus.failed,
        );
      }

      // 解析challenge（JSON格式）
      final challengeData = jsonDecode(challengeResp.body);
      final challenge = challengeData['challenge'] ?? '';
      
      // 构造登录参数（深澜协议需要加密info字段）
      final loginData = {
        'action': 'login',
        'username': config.username,
        'password': config.password,
        'ac_id': '1',
        'ip': userIp,
        'chksum': '', // 需要MD5加密，简化版先留空
        'info': '', // 需要特殊编码
        'n': '200',
        'type': '1',
      };

      final loginUrl = Uri.parse('${portalUri.origin}/cgi-bin/srun_portal');
      final loginResp = await http.post(
        loginUrl,
        body: loginData,
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(loginResp.body);
      
      if (result['error'] == 'ok' || result['suc_msg'] != null) {
        return LoginResult(
          success: true,
          message: '登录成功',
          status: LoginStatus.success,
        );
      }
      
      return LoginResult(
        success: false,
        message: result['error_msg'] ?? '登录失败',
        status: LoginStatus.failed,
      );
      
    } catch (e) {
      _logger.e('深澜登录异常: $e');
      return LoginResult(
        success: false,
        message: '登录失败: $e',
        status: LoginStatus.failed,
      );
    }
  }

  /// Dr.COM 登录
  Future<LoginResult> _loginDrCOM(Uri portalUri, PortalConfig config,
      String userIp, String mac) async {
    try {
      final postData = {
        'DDDDD': ',0,${config.username}',  // Dr.COM格式：,0,用户名@运营商
        'upass': config.password,
        '0MKKey': '123456',
      };

      final response = await http.post(
        portalUri,
        body: postData,
      ).timeout(const Duration(seconds: 15));

      if (response.body.contains('登录成功') || 
          response.statusCode == 204) {
        return LoginResult(
          success: true,
          message: '登录成功',
          status: LoginStatus.success,
        );
      }
      
      return LoginResult(
        success: false,
        message: '登录失败',
        status: LoginStatus.failed,
      );
      
    } catch (e) {
      return LoginResult(
        success: false,
        message: '登录失败: $e',
        status: LoginStatus.failed,
      );
    }
  }

  /// 通用登录方法（解析HTML表单并提交）
  Future<LoginResult> _loginGeneric(String portalUrl, PortalConfig config) async {
    try {
      // 1. 访问登录页面获取表单
      final pageResp = await http.get(Uri.parse(portalUrl))
          .timeout(const Duration(seconds: 10));
      
      if (pageResp.statusCode != 200) {
        return LoginResult(
          success: false,
          message: '无法访问认证页面',
          status: LoginStatus.failed,
        );
      }

      // 2. 解析表单
      final doc = html_parser.parse(pageResp.body);
      final form = doc.querySelector('form');
      
      if (form == null) {
        return LoginResult(
          success: false,
          message: '未找到登录表单',
          status: LoginStatus.failed,
        );
      }

      final action = form.attributes['action'] ?? portalUrl;
      final formUri = Uri.parse(action);
      
      // 3. 构造POST数据（自动识别用户名/密码字段）
      final formData = <String, String>{};
      final inputs = form.querySelectorAll('input');
      
      for (final input in inputs) {
        final name = input.attributes['name'] ?? '';
        final type = input.attributes['type'] ?? 'text';
        final value = input.attributes['value'] ?? '';
        
        if (name.isEmpty) continue;
        
        // 识别用户名字段
        if (type == 'text' || type == 'email' || type == 'tel') {
          if (name.toLowerCase().contains('user') ||
              name.toLowerCase().contains('account') ||
              name.toLowerCase().contains('name')) {
            formData[name] = config.username;
            continue;
          }
        }
        
        // 识别密码字段
        if (type == 'password') {
          formData[name] = config.password;
          continue;
        }
        
        // 其他字段保留原值
        if (value.isNotEmpty) {
          formData[name] = value;
        }
      }

      // 4. 提交表单
      final response = await http.post(
        formUri,
        body: formData,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': portalUrl,
        },
      ).timeout(const Duration(seconds: 15));

      // 5. 判断结果
      if (response.body.contains('成功') || 
          response.body.contains('success') ||
          response.statusCode == 204) {
        return LoginResult(
          success: true,
          message: '登录成功',
          status: LoginStatus.success,
        );
      }
      
      return LoginResult(
        success: false,
        message: '登录失败，请检查用户名密码',
        status: LoginStatus.failed,
      );
      
    } catch (e) {
      _logger.e('通用登录异常: $e');
      return LoginResult(
        success: false,
        message: '登录失败: $e',
        status: LoginStatus.failed,
      );
    }
  }

  /// 登出
  Future<void> logout() async {
    // TODO: 实现登出逻辑（不同Portal协议的登出接口）
    _logger.i('执行登出');
  }
}
