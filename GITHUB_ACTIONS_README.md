# GitHub Actions 自动构建完整指南

本项目使用 GitHub Actions 自动构建 Android 和 Windows 版本，**完全不需要本地安装 Android Studio**。

## ✨ 主要特性

- ✅ **零本地配置** - 所有构建在云端完成
- ✅ **自动生成代码** - 自动运行 build_runner 生成 Hive 适配器
- ✅ **多架构支持** - Android 自动生成 arm64-v8a、armeabi-v7a、x86_64 三个版本
- ✅ **智能签名** - 支持签名和未签名两种模式
- ✅ **自动发布** - 构建产物自动上传到 GitHub Release

---

## 🚀 快速开始（3步完成）

### 步骤 1: 创建标签
```bash
git tag v1.0.21
```

### 步骤 2: 推送到 GitHub
```bash
git push origin v1.0.21
```

### 步骤 3: 等待构建完成
- 访问 `https://github.com/你的用户名/kelivo/actions`
- 等待 10-15 分钟
- 在 Releases 页面下载 APK

**注意**: 标签必须以 `v` 开头，例如 `v1.0.21`、`v2.0.0` 等。

### 方法2: 手动触发

1. 访问 GitHub 仓库的 Actions 页面
2. 选择 "Build and Release" 工作流
3. 点击右侧的 "Run workflow" 按钮
4. 选择分支（通常是 main 或 master）
5. 点击绿色的 "Run workflow" 按钮

---

## 📦 构建产物

构建完成后，会自动生成以下文件：

### Android
- `kelivo-arm64-v8a-release.apk` - **64位ARM设备（主流手机，推荐）**
- `kelivo-armeabi-v7a-release.apk` - 32位ARM设备（老手机）
- `kelivo-x86_64-release.apk` - x86_64设备（模拟器）
- `kelivo-release.aab` - Google Play上传包

### Windows
- `kelivo-windows-x64.zip` - Windows 64位便携版

---

## 🔧 最近修复的问题

### 修复内容（2025-10-29）

1. **添加代码生成步骤** ✅
   - 自动运行 `build_runner` 生成 Hive 适配器（.g.dart 文件）
   - 解决了缺少 TypeAdapter 的编译错误

2. **添加 --no-tree-shake-icons 参数** ✅
   - 避免图标相关的构建错误
   - 确保所有图标在运行时可用

3. **简化 Windows 构建流程** ✅
   - 移除了不可靠的动态修改 pubspec.yaml 的逻辑
   - 依赖项目已有的条件导入机制处理 flutter_tts

4. **改进错误处理** ✅
   - 更清晰的日志输出
   - 明确区分签名和未签名构建

### 构建流程

**Android 构建步骤:**
1. 检出代码
2. 设置 Java 17 环境
3. 设置 Flutter 环境
4. 安装依赖 (`flutter pub get`)
5. 生成代码 (`build_runner`)
6. 配置签名（如果有）
7. 构建 APK（3个架构）
8. 构建 AAB
9. 重命名文件
10. 上传到 Release

**Windows 构建步骤:**
1. 检出代码
2. 设置 Flutter 环境
3. 启用 Windows 桌面支持
4. 安装依赖
5. 生成代码
6. 构建 Windows 应用
7. 打包为 ZIP
8. 上传到 Release

**预计时间:** Android 8-12分钟，Windows 6-10分钟，总计 15-20分钟

---

## 🛠️ 故障排除

### 如何查看构建日志

1. 访问 `https://github.com/你的用户名/kelivo/actions`
2. 点击失败的工作流运行（红色 ❌ 标记）
3. 点击左侧的 "build-android" 或 "build-windows"
4. 展开红色的步骤查看详细错误信息
5. 使用 Ctrl+F 搜索 "error" 或 "failed" 关键词

### 常见错误及解决方案

**错误 1: build_runner 失败**
```
错误: Could not find package build_runner
解决: 确保 pubspec.yaml 中包含 build_runner 和 hive_generator 依赖
```

**错误 2: Gradle 构建超时**
```
错误: Gradle build timed out
解决: 网络问题，重新运行工作流即可（点击 Re-run failed jobs）
```

**错误 3: NDK 版本不匹配**
```
错误: NDK version mismatch
解决: 已在 android/app/build.gradle.kts 中固定 NDK 版本为 27.0.12077973
```

**错误 4: 签名配置错误**
```
错误: Keystore file not found
解决: 不配置 GitHub Secrets 即可构建未签名 APK（可直接安装使用）
```

**错误 5: 依赖冲突**
```
错误: version solving failed
解决: 本地运行 flutter pub get 确认依赖可以解析
```

**错误 6: 内存不足**
```
错误: OutOfMemoryError: Java heap space
解决: 已在 android/gradle.properties 中配置 8G 内存，通常不会出现
```

---

## 🧪 本地测试（可选）

在推送到 GitHub 之前，可以先在本地测试：

### Android 本地测试

```bash
# 使用测试脚本（推荐）
bash scripts/test_android_build.sh

# 或手动执行
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter build apk --release --split-per-abi --no-tree-shake-icons

# 检查产物
ls -lh build/app/outputs/flutter-apk/
```

### Windows 本地测试

```powershell
# 清理
flutter clean

# 获取依赖
flutter pub get

# 生成代码
flutter pub run build_runner build --delete-conflicting-outputs

# 构建
flutter build windows --release --no-tree-shake-icons

# 检查产物
Get-ChildItem -Recurse build\windows\x64\runner\Release\
```

---

## 🔐 配置签名构建（可选）

默认构建未签名 APK，可以直接安装使用。如需签名版本（用于 Google Play）：

### 1. 生成 keystore

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 2. 转换为 base64

```bash
# Linux/Mac
base64 -i upload-keystore.jks -o keystore.base64

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore.base64
```

### 3. 配置 GitHub Secrets

在 GitHub 仓库设置中添加（Settings → Secrets and variables → Actions）:

- `KEYSTORE_BASE64`: keystore.base64 文件的完整内容
- `KEYSTORE_PASSWORD`: keystore 密码
- `KEY_PASSWORD`: key 密码
- `KEY_ALIAS`: key 别名（通常是 "upload"）

### 4. 重新运行工作流

配置完成后，工作流会自动检测并使用签名构建。

---

## ❓ 常见问题

**Q: 需要付费吗？**
A: GitHub Actions 对公开仓库免费，私有仓库每月有 2000 分钟免费额度。

**Q: APK 是签名的吗？**
A: 默认是未签名的，可以直接安装使用。如需签名版本，参考上面的签名配置。

**Q: 构建需要多久？**
A: Android 约 8-12 分钟，Windows 约 6-10 分钟，总计 15-20 分钟。

**Q: 可以只构建 Android 吗？**
A: 可以，在 Actions 页面手动触发时选择特定的 job。

**Q: 构建失败怎么办？**
A: 查看上面的"故障排除"部分，或在 Actions 日志中搜索错误信息。

---

## 📝 更新日志

- **2025-10-29**:
  - 添加自动代码生成步骤（build_runner）
  - 添加 --no-tree-shake-icons 参数避免图标问题
  - 简化 Windows 构建流程
  - 改进错误处理和日志输出
  - 添加本地测试脚本

- **2025-10-27**:
  - 简化工作流，移除签名配置
  - 提高构建可靠性
