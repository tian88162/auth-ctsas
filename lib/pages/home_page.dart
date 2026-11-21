import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portal_config.dart';
import 'settings_page.dart';
import 'logs_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('校园网自动认证'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '日志',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // 状态卡片
                _StatusCard(state: state),
                
                const SizedBox(height: 24),
                
                // 配置预览卡片
                _ConfigPreviewCard(state: state),
                
                const SizedBox(height: 24),
                
                // 操作按钮
                _ActionButtons(state: state),
                
                const SizedBox(height: 24),
                
                // 底部提示
                if (!state.config.isValid)
                  _SetupGuide(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 状态显示卡片
class _StatusCard extends StatelessWidget {
  final AppState state;
  
  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = _getStatusInfo(state.status);
    
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 状态图标（动画）
            if (state.status == LoginStatus.checking || state.status == LoginStatus.logging)
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, size: 60, color: Colors.white),
            
            const SizedBox(height: 12),
            
            // 状态标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 详细消息
            Text(
              state.message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  (IconData, Color, String) _getStatusInfo(LoginStatus status) {
    switch (status) {
      case LoginStatus.idle:
        return (Icons.wifi_off, Colors.grey, '空闲');
      case LoginStatus.checking:
        return (Icons.wifi_find, Colors.orange, '检测中');
      case LoginStatus.logging:
        return (Icons.login, Colors.blue, '登录中');
      case LoginStatus.success:
        return (Icons.check_circle, Colors.green, '已连接');
      case LoginStatus.failed:
        return (Icons.error, Colors.red, '登录失败');
      case LoginStatus.offline:
        return (Icons.wifi_off, Colors.grey, '未连接WiFi');
    }
  }
}

/// 配置预览卡片
class _ConfigPreviewCard extends StatelessWidget {
  final AppState state;
  
  const _ConfigPreviewCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final config = state.config;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                const Text('账号', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  config.username.isNotEmpty 
                      ? config.username 
                      : '未配置',
                  style: TextStyle(
                    color: config.username.isNotEmpty 
                        ? Colors.black 
                        : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.link, size: 20),
                const SizedBox(width: 8),
                const Text('门户地址', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Flexible(
                  child: Text(
                    config.portalUrl.isNotEmpty
                        ? _truncateUrl(config.portalUrl)
                        : '自动检测',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.autorenew, size: 20),
                const SizedBox(width: 8),
                const Text('自动登录', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(config.autoLogin ? '已开启' : '已关闭'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _truncateUrl(String url) {
    if (url.length <= 30) return url;
    return '${url.substring(0, 30)}...';
  }
}

/// 操作按钮组
class _ActionButtons extends StatelessWidget {
  final AppState state;
  
  const _ActionButtons({required this.state});

  @override
  Widget build(BuildContext context) {
    final isLoading = state.status == LoginStatus.checking || 
                      state.status == LoginStatus.logging;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 手动登录按钮
        FilledButton.icon(
          onPressed: isLoading || !state.config.isValid
              ? null
              : () async {
                  final result = await state.login();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor: result.success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.login),
          label: Text(isLoading ? '登录中...' : '手动登录'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 自动监听开关
        OutlinedButton.icon(
          onPressed: () {
            if (state.isMonitoring) {
              state.stopMonitoring();
            } else {
              state.startMonitoring();
            }
          },
          icon: Icon(state.isMonitoring ? Icons.pause : Icons.play_arrow),
          label: Text(state.isMonitoring ? '停止自动监听' : '开启自动监听'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

/// 未配置时的引导提示
class _SetupGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '完成配置以启用自动登录',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击右上角设置图标填写校园网账号密码',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
              child: const Text('前往'),
            ),
          ],
        ),
      ),
    );
  }
}
