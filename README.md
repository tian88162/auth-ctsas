# 校园网自动认证 - 手机端

**一键登录校园网，自动监听WiFi连接状态并认证**

> 基于 Flutter 开发，支持 Android 和 iOS（主要针对Android优化）

---

## 功能特性

✅ **自动认证**：连接校园网WiFi后自动登录，无需手动操作  
✅ **多协议支持**：VBRAS/锐捷、深澜SRUN、Dr.COM等主流校园网Portal  
✅ **后台监听**：长期驻后台监听网络变化，掉线自动重连  
✅ **开机自启**：系统启动后自动激活监听服务  
✅ **智能检测**：自动识别Portal类型和认证参数  
✅ **安全可靠**：配置本地加密存储，不上传任何数据  

---

## 快速开始

### 针对你的校园网（VBRAS Portal）

你的认证门户地址：`http://172.32.253.17/portal.do?...`

**步骤：**

1. **安装应用**（见下方编译说明）
2. **填写配置**：
   - 打开APP，点击右上角"设置"图标
   - 填写**校园网账号**（学号/工号）
   - 填写**密码**
   - **门户地址**可留空（会自动检测），或填入：
     ```
     http://172.32.253.17/portal.do
     ```
   - 开启"自动登录"开关
   - 点击"保存"

3. **测试登录**：
   - 返回主界面，点击"手动登录"按钮测试
   - 成功后，以后每次连WiFi都会自动认证

4. **后台保活**（重要）：
   - 进入系统设置 → 应用管理 → 校园网认证
   - 关闭"电池优化"（允许后台运行）
   - 开启"自启动"权限
   - 授予"通知"权限

---

## 编译安装

### 前提条件

- Flutter SDK (>=3.0.0)
- Android Studio / Xcode
- Android设备 或 模拟器

### 编译步骤

```bash
# 1. 进入项目目录
cd campus_auth_mobile

# 2. 获取依赖
flutter pub get

# 3. 连接手机或启动模拟器

# 4. 编译并安装（Debug版本）
flutter run

# 或 编译Release APK
flutter build apk --release
# APK输出路径：build/app/outputs/flutter-apk/app-release.apk
```

---

## 使用说明

### 主界面

- **状态卡片**：显示当前认证状态（检测中/登录中/已连接/失败）
- **配置预览**：查看当前账号和门户地址
- **手动登录**：立即触发一次认证
- **自动监听开关**：开启/关闭后台WiFi状态监听

### 设置页面

#### 账号信息
- **校园网账号**：你的学号或工号
- **密码**：校园网认证密码

#### 认证门户
- **门户地址**：认证页面URL，可选填
  - 留空：每次自动检测（访问公网时被302跳转到的地址）
  - 填写：固定使用指定地址（推荐，速度更快）
  
  **获取门户地址方法：**
  1. 连接校园网WiFi
  2. 打开浏览器访问任意网站（如baidu.com）
  3. 自动跳转到认证页面，复制地址栏的URL
  4. 粘贴到"门户地址"输入框

#### 自动化
- **自动登录**：连接WiFi时自动认证（推荐开启）
- **登录通知**：认证成功时弹出通知

---

## 支持的校园网类型

| 协议类型 | 厂商 | 识别特征 | 状态 |
|---------|------|---------|------|
| **VBRAS Portal** | 华三/锐捷 | `portal.do` / `eportal` | ✅ 支持 |
| **深澜SRUN** | 深澜 | `srun_portal` / `get_challenge` | ✅ 支持 |
| **Dr.COM** | 城市热点 | `drcom` / `0.0.0.0` | ✅ 支持 |
| **通用Portal** | 其他 | HTML表单自动解析 | ⚠️ 基础支持 |

你的校园网是 **VBRAS Portal** 类型（常见于华三H3C、锐捷Ruijie设备）。

---

## 工作原理

```
1. WiFi状态监听
   ↓
2. 检测是否需要认证（访问 generate_204 检测地址）
   ↓
3. 获取Portal跳转URL（从302响应头提取）
   ↓
4. 分析Portal类型（VBRAS/SRUN/DrCOM/通用）
   ↓
5. 提取认证参数（wlanuserip、mac、rand等）
   ↓
6. 构造并发送POST请求
   ↓
7. 解析响应判断成功/失败
   ↓
8. 失败则根据错误类型决定重试或提示
```

### 关于你的Portal

**参数分析：**
```
http://172.32.253.17/portal.do?
  wlanuserip=172.34.17.168    # 你的IP（动态获取）
  wlanacname=VBRAS-ZHKJ3       # AC控制器名称
  mac=a8:11:22:ac:00:00        # MAC地址
  vlan=0                       # VLAN ID
  rand=58009c04d5f6c4          # 随机值（防重放）
  url=http://...               # 认证后跳转地址
```

**登录请求示例：**
```http
POST http://172.32.253.17/portal.do HTTP/1.1
Content-Type: application/x-www-form-urlencoded

DDDDD=你的学号&upass=你的密码&R1=0&R2=&R3=0&R6=0&para=00&0MKKey=123456
```

---

## 故障排查

### 1. 登录失败：用户名或密码错误
- 检查账号密码是否正确
- 确认是否需要加运营商后缀（如 `@cmcc`）

### 2. 登录失败：无法检测到认证门户
- **手动填写门户地址**：
  1. 连WiFi后用浏览器打开任意网站
  2. 复制跳转后的认证页面URL
  3. 粘贴到APP设置中的"门户地址"

### 3. 自动登录不生效
- 检查"自动登录"开关是否开启
- 确认系统给予了以下权限：
  - 允许后台运行（关闭电池优化）
  - 开启自启动
  - 允许发送通知

### 4. 后台被系统杀掉
**国产手机特别优化：**
- **小米MIUI**：安全中心 → 应用管理 → 权限 → 自启动 → 开启
- **华为EMUI**：手机管家 → 应用启动管理 → 手动管理 → 全部允许
- **OPPO/一加**：设置 → 应用管理 → 应用列表 → 校园网认证 → 允许后台活动
- **vivo**：i管家 → 应用管理 → 权限管理 → 自启动 → 允许

### 5. 提示"账户欠费"或"已在线"
- **欠费**：去充值平台充值
- **已在线**：可能其他设备正在使用，需先在那边退出登录

---

## 高级功能（TODO）

- [ ] 多账号支持（家人/备用账号）
- [ ] 按SSID自动切换配置
- [ ] 流量统计
- [ ] 定时自动重连（如每天凌晨重新认证）
- [ ] 验证码识别（OCR）
- [ ] 日志详细记录与导出
- [ ] 桌面小部件（快速查看状态）

---

## 开发说明

### 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/
│   └── portal_config.dart    # 配置数据模型
├── services/
│   ├── portal_service.dart   # Portal认证核心逻辑
│   ├── wifi_monitor.dart     # WiFi状态监听
│   └── config_service.dart   # 配置存储
└── pages/
    ├── home_page.dart        # 主界面
    ├── settings_page.dart    # 设置页面
    └── logs_page.dart        # 日志页面

android/
└── app/src/main/kotlin/com/campusauth/app/
    ├── WiFiReceiver.kt       # WiFi广播接收器
    ├── BootReceiver.kt       # 开机自启接收器
    └── CampusAuthWorker.kt   # 后台任务Worker
```

### 添加新的Portal协议

编辑 `lib/services/portal_service.dart`，在 `_executeLogin` 方法中添加新的判断分支：

```dart
// 检测门户类型
if (portalUrl.contains('你的特征关键字')) {
  return await _loginYourPortal(uri, config, ...);
}
```

然后实现 `_loginYourPortal` 方法。

---

## 安全说明

- 账号密码**本地加密存储**（SharedPreferences），不上传任何服务器
- 所有HTTP请求直达校园网门户，不经过第三方
- 开源代码，可自行审计

---

## 许可证

MIT License

---

## 致谢

- 灵感来源：[campus-auth](https://github.com/xxx/campus-auth) Windows版
- 依赖库：Flutter、connectivity_plus、workmanager等

---

## 联系方式

遇到问题或建议？欢迎提Issue！

**祝你上网愉快！🎉**
