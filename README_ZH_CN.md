<div align="center">
  <img src="assets/app_icon.png" alt="Kelivo Icon" width="100" />
  <h1>Kelivo</h1>
  <p>一个现代化的 Flutter LLM 聊天客户端</p>

  <a href="https://discord.gg/Tb8DyvvV5T" target="_blank">
    <img src="https://img.shields.io/badge/Join%20our%20Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Join Discord"/>
  </a>

  <br/><br/>
  <a href="README.md">English</a> | 简体中文
</div>

## 📥 下载

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/kelivo/id6752122930)

- 🔗 [下载最新版本](https://github.com/Chevey339/kelivo/releases/latest)
- 🧪 [TestFlight 测试版](https://testflight.apple.com/join/PZZyRMyY)

<div align="center">
  <img src="docx/screenshot_1.png" alt="聊天界面" width="150" />
  <img src="docx/screenshot_2.png" alt="模型选择" width="150" />
  <img src="docx/screenshot_3.png" alt="工具调用" width="150" />
  <img src="docx/screenshot_4.png" alt="网络搜索" width="150" />
</div>

## ✨ 核心特性

- 🎨 **现代设计** - Material You 动态配色（Android 12+）与深色模式支持
- 🌍 **多语言** - 支持中英文界面
- 🔄 **多提供商** - 支持 OpenAI、Gemini、Anthropic 等主流 AI 服务
- 🤖 **自定义助手** - 创建个性化 AI 助手
- 🖼️ **多模态输入** - 支持图片、文档、PDF、Word 等多种格式
- 📝 **Markdown 渲染** - 完整支持代码高亮、LaTeX 公式、表格等
- 🎙️ **语音功能** - 内置系统 TTS 语音播报
- 🛠️ **MCP 支持** - Model Context Protocol 工具集成
- 🔍 **网络搜索** - 集成多个搜索引擎（Exa、Tavily、知谱、Brave、Bing、Metaso 等）
- 🧩 **Prompt 变量** - 支持模型名称、时间等动态变量
- 📤 **二维码分享** - 通过二维码导入导出配置
- 💾 **数据备份** - 支持聊天记录备份与恢复

## 📱 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| Android | ✅ 已支持 | Android 5.0+ |
| iOS | ✅ 已支持 | iOS 12.0+ |
| Harmony | ✅ 已支持 | [kelivo-ohos](https://github.com/Chevey339/kelivo-ohos) |
| Windows | 🚧 计划中 | - |
| macOS | 🚧 计划中 | - |
| Web | 🚧 实验性 | - |

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.8.1 或更高版本
- Dart SDK 3.8.1 或更高版本
- Android Studio / Xcode（针对移动平台开发）

### 安装依赖

```bash
# 获取项目依赖
flutter pub get

# 生成代码（Hive、国际化等）
flutter pub run build_runner build --delete-conflicting-outputs
```

### 开发运行

```bash
# 运行调试版本（自动检测设备）
flutter run

# 指定设备运行
flutter run -d <device_id>

# 热重载快捷键：按 'r'
# 热重启快捷键：按 'R'
```

### 构建发布

```bash
# Android APK
flutter build apk --release

# Android App Bundle（推荐用于 Google Play）
flutter build appbundle --release

# iOS（需要在 macOS 上）
flutter build ios --release

# Web
flutter build web --release

# Windows（需要在 Windows 上）
flutter build windows --release
```

### 代码质量

```bash
# 代码分析
flutter analyze

# 运行测试
flutter test

# 格式化代码
dart format .
```

## 🔧 项目结构

```
kelivo/
├── lib/
│   ├── core/          # 核心模型、服务、提供者
│   ├── features/      # 功能模块（聊天、设置、搜索等）
│   ├── desktop/       # 桌面端特定 UI
│   ├── shared/        # 共享组件
│   ├── theme/         # 主题配置
│   ├── l10n/          # 国际化文件
│   └── main.dart      # 应用入口
├── assets/            # 静态资源（图标、图片等）
├── android/           # Android 原生配置
├── ios/               # iOS 原生配置
└── web/               # Web 配置
```

## ❓ 常见问题

### 1. 构建失败：找不到依赖

```bash
# 清理并重新获取依赖
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. iOS 构建失败

```bash
# 清理 iOS 构建缓存
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter build ios
```

### 3. Android 签名配置

创建 `android/key.properties` 文件并配置签名信息：

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=<path-to-keystore>
```

### 4. 如何添加新的 AI 提供商？

参考 `lib/features/provider/` 目录下的现有实现，创建新的提供商配置类。

### 5. 数据存储在哪里？

应用使用 Hive 本地数据库，数据存储位置：
- Android: `/data/data/com.kelivo.app/`
- iOS: 应用沙盒目录
- Windows/macOS: 用户文档目录

## 🤝 贡献指南

欢迎提交 Pull Request 和 Issue！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

## 💖 赞助商

感谢 [siliconflow.cn](https://siliconflow.cn) 提供免费模型支持。

## ❤️ 致谢

特别感谢 [RikkaHub](https://github.com/re-ovo/rikkahub) 项目提供的 UI 设计灵感。

## ⭐ Star History

如果你喜欢这个项目，请给个 Star ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=Chevey339/kelivo&type=Date)](https://star-history.com/#Chevey339/kelivo&Date)

## 📄 许可证

本项目采用 AGPL-3.0 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 📞 联系我们

- Issue: [GitHub Issues](https://github.com/Chevey339/kelivo/issues)
- Discord: [加入我们的社区](https://discord.gg/Tb8DyvvV5T)

---

<div align="center">
Made with ❤️ using Flutter
</div>
