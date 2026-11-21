import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/portal_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _portalUrlCtrl;
  bool _obscurePassword = true;
  bool _autoLogin = true;
  bool _notifyOnLogin = true;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppState>().config;
    _usernameCtrl = TextEditingController(text: config.username);
    _passwordCtrl = TextEditingController(text: config.password);
    _portalUrlCtrl = TextEditingController(text: config.portalUrl);
    _autoLogin = config.autoLogin;
    _notifyOnLogin = config.notifyOnLogin;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _portalUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- 账号信息 ----
            _SectionHeader(title: '账号信息', icon: Icons.person),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    ListTile(
                      title: TextFormField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: '校园网账号',
                          hintText: '学号或工号',
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.text,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '请填写账号' : null,
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      title: TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: '密码',
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '请填写密码' : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ---- 门户配置 ----
            _SectionHeader(title: '认证门户', icon: Icons.link),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ListTile(
                  title: TextFormField(
                    controller: _portalUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: '门户地址（可选）',
                      hintText: '留空则自动检测\n如：http://172.32.253.17/portal.do',
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.url,
                    maxLines: 2,
                  ),
                ),
              ),
            ),
            
            // 门户地址填写提示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                '💡 提示：连接校园网WiFi后，打开浏览器会自动跳转到认证页面，把地址栏的URL复制过来即可。'
                '留空则每次连WiFi时自动检测。',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ---- 自动化设置 ----
            _SectionHeader(title: '自动化', icon: Icons.autorenew),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _autoLogin,
                    onChanged: (v) => setState(() => _autoLogin = v),
                    title: const Text('自动登录'),
                    subtitle: const Text('连接校园网WiFi时自动认证'),
                    secondary: const Icon(Icons.login),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: _notifyOnLogin,
                    onChanged: (v) => setState(() => _notifyOnLogin = v),
                    title: const Text('登录通知'),
                    subtitle: const Text('认证成功时显示通知'),
                    secondary: const Icon(Icons.notifications),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ---- 高级设置 ----
            _SectionHeader(title: '高级', icon: Icons.tune),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text('调试模式'),
                    subtitle: const Text('显示详细日志'),
                    trailing: Switch(
                      value: false,
                      onChanged: null, // TODO
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.wifi_find),
                    title: const Text('测试连接'),
                    subtitle: const Text('立即检测当前网络状态'),
                    onTap: _testConnection,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 保存按钮
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    final config = PortalConfig(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      portalUrl: _portalUrlCtrl.text.trim(),
      autoLogin: _autoLogin,
      notifyOnLogin: _notifyOnLogin,
    );
    
    context.read<AppState>().updateConfig(config);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('配置已保存'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.pop(context);
  }
  
  void _testConnection() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在检测...')),
    );
    // TODO: 实际触发检测
    context.read<AppState>().login();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
