# GitHub Actions 自动构建说明

本项目使用 GitHub Actions 自动构建 Android 和 Windows 版本。

## 🚀 触发构建

### 方法1: 推送标签（推荐）

```bash
# 创建新标签
git tag v1.0.20

# 推送标签到 GitHub
git push origin v1.0.20
```

### 方法2: 手动触发

1. 访问 GitHub 仓库的 Actions 页面
2. 选择 "Build and Release" 工作流
3. 点击 "Run workflow" 按钮
4. 选择分支并运行

## 📦 构建产物

构建完成后，会自动生成以下文件：

### Android
- `kelivo-armeabi-v7a-release.apk` - 32位ARM设备
- `kelivo-arm64-v8a-release.apk` - 64位ARM设备（主流）
- `kelivo-x86_64-release.apk` - x86_64设备
- `kelivo-release.aab` - Google Play上传包

### Windows
- `kelivo-windows-x64.zip` - Windows 64位便携版

## 📋 工作流说明

### 简化设计
- ✅ **无需配置 Secrets** - 构建未签名版本，简单可靠
- ✅ **自动重命名** - 所有文件自动添加 kelivo 前缀
- ✅ **缓存优化** - 使用 Flutter 和 Gradle 缓存加速构建
- ✅ **错误处理** - 详细的日志输出，便于调试
- ✅ **自动发布** - 构建产物自动附加到 GitHub Release

### 构建时间
- Android: 约 5-10 分钟
- Windows: 约 5-10 分钟
- 总计: 约 10-15 分钟

## 🔍 查看构建状态

访问以下链接查看构建进度：
```
https://github.com/KianaMei/kelivo/actions
```

## ⚠️ 注意事项

1. **APK 未签名**: 生成的 APK 是未签名的，可以直接安装使用，但不能上传到 Google Play
2. **如需签名版本**: 需要配置 Android 签名密钥，但这会增加配置复杂度
3. **Windows 便携版**: 解压即用，无需安装

## 🛠️ 故障排除

### 构建失败怎么办？

1. 查看 Actions 日志获取详细错误信息
2. 常见问题：
   - Flutter 版本问题：工作流使用 stable 频道
   - 依赖问题：检查 pubspec.yaml
   - 平台特定问题：查看对应平台的构建日志

### 如何本地测试？

```bash
# Android
flutter build apk --release --split-per-abi

# Windows
flutter build windows --release
```

## 📝 更新日志

- 2025-10-27: 简化工作流，移除签名配置，提高可靠性
