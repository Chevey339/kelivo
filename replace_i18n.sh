#!/bin/bash

# 这是一个示例脚本，用于查找和替换项目中的条件逻辑
# 搜索包含 zh ? 'text' : 'text' 模式的文件

echo "正在查找需要替换的文件..."

# 查找所有包含条件逻辑的 Dart 文件
find lib/ -name "*.dart" -type f -exec grep -l "zh.*?.*:.*" {} \; > files_to_replace.txt

echo "找到以下需要替换的文件:"
cat files_to_replace.txt

echo ""
echo "请按照以下步骤手动替换:"
echo "1. 在每个文件中导入: import '../../../l10n/app_localizations.dart';"
echo "2. 添加: final l10n = AppLocalizations.of(context)!;"
echo "3. 将 zh ? '中文' : 'English' 替换为 l10n.keyName"
echo "4. 在 app_en.arb 和 app_zh.arb 中添加对应的键值对"
echo "5. 运行 flutter gen-l10n 重新生成本地化文件"

# 清理临时文件
rm -f files_to_replace.txt