# Windows 构建指南

本文档说明如何为 Windows 平台构建 Kelivo 应用程序。

---

## 📋 更新说明

### 最新修复 (2025-10-29)

#### 🎨 修复思考内容中 Markdown 标题显示问题

**问题描述**:
- 思考内容（Reasoning/Thinking）中的 Markdown 标题没有换行
- 标题直接跟在前面的文字后面，显示拥挤
- 例如: "...some text.Providing user support" (标题紧贴前文)

**修复内容**:
- 修改 `lib/shared/widgets/markdown_with_highlight.dart`
- 增加 ATX 标题（`#`、`##` 等）的上边距
- 增加 Setext 标题（下划线风格）的上边距
- H1: 上边距 12px，下边距 6px
- H2: 上边距 10px，下边距 5px
- H3: 上边距 8px，下边距 4px
- H4-H6: 上边距 6px，下边距 3px

**影响范围**:
- 所有 Markdown 渲染场景（聊天消息、思考内容等）
- 标题现在会与前面的内容明显分隔

---

#### 🔧 修复 OpenAI Response API 工具格式问题

**问题描述**:
- 使用 Response API (`/responses`) 时，工具调用返回 500 错误
- 错误信息: `Missing required parameter: 'tools[0].name'`
- 原因: Response API 的工具格式与 Chat Completions API 不同

**修复内容**:
- 修改 `lib/core/services/api/chat_api_service.dart`
- 添加工具格式自动转换逻辑
- Chat Completions 格式: `{"type": "function", "function": {"name": "...", ...}}`
- Response API 格式: `{"type": "function", "name": "...", ...}` (扁平化)

**影响范围**:
- 所有使用 Response API 的提供商 (如 gpt-5-nano-2025-08-07)
- 工具调用功能 (search_web 等)

---

### 修改的文件
- **`scripts/build_windows.ps1`** - 添加详细帮助文档，`DisableTts` 默认为 `$true`
- **`lib/core/services/tts/tts_factory_io.dart`** - Windows 平台始终返回 `TtsStub()`
- **`README.md` / `README_ZH_CN.md`** - Windows 平台状态更新为 "✅ 已支持"
- **`lib/features/home/pages/home_page.dart`** - 添加 `isEmbeddedInDesktopNav` 参数，修复 Windows 桌面版左下角重复设置按钮问题
- **`lib/desktop/desktop_chat_page.dart`** - 传递 `isEmbeddedInDesktopNav: true` 参数
- **`lib/core/services/api/chat_api_service.dart`** - 修复 Response API 工具格式转换问题
- **`lib/shared/widgets/markdown_with_highlight.dart`** - 增加 Markdown 标题的上下边距，修复思考内容显示问题
- **所有设置子页面** - 添加 `embedded` 参数，支持在桌面设置页面中内联显示：
  - `lib/features/provider/pages/providers_page.dart`
  - `lib/features/assistant/pages/assistant_settings_page.dart`
  - `lib/features/model/pages/default_model_page.dart`
  - `lib/features/search/pages/search_services_page.dart`
  - `lib/features/mcp/pages/mcp_page.dart`
  - `lib/features/quick_phrase/pages/quick_phrases_page.dart`
  - `lib/features/settings/pages/tts_services_page.dart`
  - `lib/features/backup/pages/backup_page.dart`
  - `lib/features/settings/pages/about_page.dart`
- **`lib/desktop/desktop_settings_page.dart`** - 所有设置子页面的包装组件都使用 `embedded: true` 参数

### 新增的文件
- **`build_windows_simple.bat`** - 一键构建脚本
- **`BUILD_WINDOWS.md`** - 本文档

### 主要改进
- ✅ 默认禁用 TTS（无需 NUGET.EXE）
- ✅ 一键构建脚本
- ✅ 完善的文档和错误提示
- ✅ 修复 Windows 桌面版左下角重复设置按钮的 UI 问题
- ✅ 修复桌面设置页面导航问题：点击设置菜单项时，内容在右侧面板内联显示，而不是跳转到新页面
- ✅ 修复 OpenAI Response API 工具格式问题：自动转换 Chat Completions 格式到 Response API 扁平化格式
- ✅ 修复思考内容 Markdown 标题显示问题：标题现在会与前面的内容明显分隔，不再紧贴

---

## 🚀 快速开始

### 方法 1: 使用简化脚本（推荐）

双击运行项目根目录下的 `build_windows_simple.bat` 文件即可开始构建。

### 方法 2: 使用命令行

```powershell
# 标准构建
.\scripts\build_windows.bat

# 或者使用 PowerShell
.\scripts\build_windows.ps1

# 清理构建
.\scripts\build_windows.ps1 -Clean
```

## 构建要求

### 必需软件

1. **Flutter SDK** (3.35.7 或更高版本)
   - 脚本会自动检测以下位置的 Flutter SDK：
     - `.flutter/bin/` (项目本地)
     - `flutter/bin/` (项目本地)
     - 系统 PATH 环境变量

2. **Visual Studio Build Tools**
   - Visual Studio 2022 Build Tools (推荐)
   - 或 Visual Studio 2019 Build Tools
   - 需要安装 "使用 C++ 的桌面开发" 工作负载

3. **CMake** (通常随 Visual Studio Build Tools 安装)

### 可选软件

- **NUGET.EXE** - 仅在需要启用 TTS 功能时需要

## 构建选项

### 默认构建（推荐）

```powershell
.\scripts\build_windows.ps1
```

- 自动禁用 `flutter_tts` 插件（避免 NUGET.EXE 依赖）
- TTS 功能在 Windows 上使用 stub 实现
- 构建速度快，无额外依赖

### 清理构建

```powershell
.\scripts\build_windows.ps1 -Clean
```

删除所有构建缓存后重新构建，适用于：
- 构建出现问题时
- 切换 Flutter 版本后
- 依赖项发生重大变化后

### 启用 TTS 构建（高级）

```powershell
.\scripts\build_windows.ps1 -DisableTts:$false
```

**注意**: 需要先安装 NUGET.EXE 并配置到系统 PATH。

## 构建输出

构建成功后，会生成以下文件：

### 1. 可执行文件
```
build/windows/x64/runner/Release/kelivo.exe
```

### 2. 便携版文件夹
```
dist/kelivo-windows-x64/
├── kelivo.exe                    # 主程序
├── flutter_windows.dll           # Flutter 引擎
├── *.dll                         # 插件 DLL 文件
└── data/                         # 应用资源
    ├── icudtl.dat
    ├── flutter_assets/
    └── ...
```

### 3. 分发包
```
dist/kelivo-windows-x64.zip       # 约 18-20 MB
```

## 使用构建产物

### 本地运行

进入 `dist/kelivo-windows-x64/` 文件夹，双击 `kelivo.exe` 即可运行。

### 分发给用户

1. 将 `dist/kelivo-windows-x64.zip` 发送给用户
2. 用户解压 ZIP 文件
3. 双击 `kelivo.exe` 运行

**注意**: 整个文件夹中的所有文件都是必需的，不能只复制 `.exe` 文件。

## 常见问题

### 1. Flutter 未找到

**错误**: `flutter CLI not found`

**解决方案**:
- 确保 Flutter SDK 已安装
- 将 Flutter SDK 的 `bin` 目录添加到系统 PATH
- 或将 Flutter SDK 复制到项目根目录下的 `flutter/` 文件夹

### 2. CMake 错误

**错误**: `CMake Error` 或 `MSVC toolchain not found`

**解决方案**:
- 安装 Visual Studio 2022 Build Tools
- 确保安装了 "使用 C++ 的桌面开发" 工作负载
- 重启命令行窗口

### 3. NUGET.EXE 未找到

**错误**: `NUGET.EXE not found`

**解决方案**:
- 这是正常的，默认构建会禁用需要 NUGET 的插件
- 如果看到此警告但构建成功，可以忽略
- TTS 功能在 Windows 上使用 stub 实现，不影响其他功能

### 4. 构建失败

**解决方案**:
1. 尝试清理构建：
   ```powershell
   .\scripts\build_windows.ps1 -Clean
   ```

2. 删除构建缓存：
   ```powershell
   flutter clean
   ```

3. 更新依赖：
   ```powershell
   flutter pub get
   ```

4. 检查 Flutter 版本：
   ```powershell
   flutter --version
   flutter doctor
   ```

## 技术说明

### TTS (文字转语音) 功能

- **移动平台** (Android/iOS): 使用 `flutter_tts` 插件的完整实现
- **Windows 平台**: 使用 stub 实现（空操作）
- **原因**: `flutter_tts` 在 Windows 上需要 NUGET.EXE 和额外配置

实现细节：
- `lib/core/services/tts/tts_factory.dart` - 平台检测和工厂
- `lib/core/services/tts/tts_factory_io.dart` - Windows 返回 stub
- `lib/core/services/tts/tts_stub.dart` - Windows stub 实现
- `lib/core/services/tts/tts_impl.dart` - 移动平台真实实现

### 条件编译

项目使用 Dart 的条件导入机制来处理平台差异：
```dart
import 'tts_stub.dart' if (dart.library.io) 'tts_factory_io.dart' as tts_factory;
```

这确保了：
- Web 平台使用 stub
- IO 平台（包括 Windows）根据运行时检测选择实现
- 编译时不会因为缺少依赖而失败

## 版本信息

- **应用版本**: 1.1.0+14 (见 `pubspec.yaml`)
- **Flutter 版本**: 3.35.7 (推荐)
- **Dart 版本**: 3.9.2

---

## 📊 测试结果

- ✅ 构建成功（约 71 秒）
- ✅ 生成可执行文件 `kelivo.exe`
- ✅ 生成便携版文件夹
- ✅ 生成分发包 ZIP (18.52 MB)
- ✅ 应用可正常运行
- ✅ TTS 功能在 Windows 上使用 stub（符合预期）

## 🐛 已修复的问题

### Windows 桌面版左下角重复设置按钮问题

**问题描述**：
- Windows 桌面版左下角出现两个设置按钮
- 最左边的设置按钮（来自 `SideDrawer` 底部栏）
- 右边的设置按钮（来自 `DesktopNavRail`）
- 导致 UI 混乱和功能重复

**根本原因**：
- `DesktopHomePage` 包含 `DesktopNavRail`（左侧导航栏，有用户头像和设置按钮）
- `DesktopChatPage` 内部调用 `HomePage`，显示 `SideDrawer`（左侧边栏）
- `SideDrawer` 的 `showBottomBar: true` 导致底部也显示用户头像和设置按钮
- 两个组件的设置按钮同时显示，造成重复

**解决方案**：
1. 给 `HomePage` 添加 `isEmbeddedInDesktopNav` 参数
2. 当 `isEmbeddedInDesktopNav: true` 时，`SideDrawer` 的 `showBottomBar` 设置为 `false`
3. `DesktopChatPage` 调用 `HomePage(isEmbeddedInDesktopNav: true)`
4. 这样在桌面版中，只显示 `DesktopNavRail` 的设置按钮，隐藏 `SideDrawer` 的底部栏

**修改的文件**：
- `lib/features/home/pages/home_page.dart` - 添加参数和逻辑
- `lib/desktop/desktop_chat_page.dart` - 传递参数

---

## 🔮 未来改进方向

- 研究 Windows 原生 TTS API 集成
- 创建 NSIS 或 Inno Setup 安装程序
- 集成应用内自动更新检查
- 添加数字签名以避免 SmartScreen 警告
- 在 GitHub Actions 中自动构建 Windows 版本

## 更多信息

- [Flutter Windows 桌面支持](https://docs.flutter.dev/desktop)
- [项目 README](README.md)
- [发布说明](RELEASE.md)

