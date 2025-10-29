#!/bin/bash

# Android 构建测试脚本
# 用于在本地测试 GitHub Actions 的构建流程

set -e  # 遇到错误立即退出

echo "========================================="
echo "Android 构建测试脚本"
echo "========================================="
echo ""

# 1. 检查 Flutter 环境
echo "步骤 1/6: 检查 Flutter 环境..."
flutter doctor -v
echo ""

# 2. 清理旧的构建文件
echo "步骤 2/6: 清理旧的构建文件..."
flutter clean
rm -rf build/
echo "✓ 清理完成"
echo ""

# 3. 获取依赖
echo "步骤 3/6: 获取依赖..."
flutter pub get
echo "✓ 依赖获取完成"
echo ""

# 4. 生成必要的文件
echo "步骤 4/6: 生成 Hive 适配器等文件..."
flutter pub run build_runner build --delete-conflicting-outputs
echo "✓ 文件生成完成"
echo ""

# 5. 构建 APK
echo "步骤 5/6: 构建 APK..."
flutter build apk --release --split-per-abi --no-tree-shake-icons
echo "✓ APK 构建完成"
echo ""

# 6. 显示构建产物
echo "步骤 6/6: 构建产物列表"
echo "========================================="
ls -lh build/app/outputs/flutter-apk/*.apk
echo "========================================="
echo ""

echo "✅ 所有步骤完成！"
echo ""
echo "APK 文件位置: build/app/outputs/flutter-apk/"

