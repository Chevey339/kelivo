# 发布指南

## 自动发布流程

本项目已配置GitHub Actions自动构建。当您创建一个新的Release时，将自动触发构建流程。

### 步骤：

1. **推送代码和标签到GitHub**
   ```bash
   git push origin master
   git push origin v1.0.17
   ```

2. **在GitHub上创建Release**
   - 访问 https://github.com/你的用户名/kelivo/releases
   - 点击 "Draft a new release"
   - 选择标签 `v1.0.17`
   - 填写Release标题和说明
   - 点击 "Publish release"

3. **自动构建**
   GitHub Actions会自动：
   - 构建Android APK (分架构)
   - 构建Android App Bundle (.aab)
   - 构建Windows版本 (.zip)
   - 构建Linux版本 (.tar.gz)
   - 将构建产物自动上传到Release

## 本地构建

### Android APK
```bash
flutter build apk --release --split-per-abi
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### Windows
```bash
flutter config --enable-windows-desktop
flutter build windows --release
```

### Linux
```bash
flutter config --enable-linux-desktop
flutter build linux --release
```

## 版本说明 v1.0.17

### 新功能
- ✨ 改进的加载动画效果
  - 支持多种动画风格（shimmer、pulse、typewriter、modern）
  - 现代化的波浪加载效果
- 🔧 修复思考内容的Markdown渲染
  - 现在可以正确显示粗体、斜体、代码块等格式
- 🔧 修复网页版侧边栏底部设置按钮不显示的问题

### 技术改进
- 创建了AnimatedLoadingText和ModernLoadingIndicator组件
- 升级了项目依赖包
- 添加了GitHub Actions自动构建配置
