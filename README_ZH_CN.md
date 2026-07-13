<div align="center">
  <img src="assets/app_icon.png" alt="Cuplivo Icon" width="100" />
  <h1>为什么选择 Cuplivo？</h1>

  一个 Flutter LLM 聊天客户端 — 社区分支
  
  Kelivo 二群 (QQ) `856321431`

  [Read the English version](README.md)
</div>

### 兼容性

Cuplivo 是 [Kelivo](https://github.com/Chevey339/kelivo) 的社区分支，保持完整数据兼容。配置 WebDAV 或 S3，恢复从 Kelivo 导出的备份文件即可无缝接续，无需重新配置。界面整体没有大幅改动，原有用户可以快速适应。

目前已知作者本人和至少 2 位稳定用户在使用，未遇到问题。安装 Cuplivo 无需卸载 Kelivo，数据安全双重保障。

### 新功能

1. **SQLite 存储** — 使用 SQLite 替换了 Hive，以提升可靠性。助手存储（SharedPreferences）也已一并迁移至 SQLite，覆盖面进一步扩大。
   - 预估：数据丢失事件的发生概率预计降低约 90%。
   - 备注：现有的 `.zip` 备份仍完全兼容，因为它们并非原始的 Hive 二进制文件。

2. **增量备份** — 仅上传自某个选定日期以来的对话和消息，以及附件等。
   - 实测：一次 12.6 MB 的完整备份后，通常仅会产生 50 KB 至 1.5 MB 的增量上传。随着附件和图片的积累，节省效果会更加明显。这降低了带宽与存储开销，也有助于养成更频繁的备份习惯。
   - 注意：仍建议定期进行完整快照备份。

3. **手动图片压缩** — 手机照片和桌面截图虽然像素清晰，但对于 LLM 任务往往属于过度冗余。
   - 实测：将长边从 4096 px 调整为 2048 px，文件大小可从 2.06 MB 降至约 425 KB，输入 Token 从 8,136 减至 3,096，且模型回复质量无肉眼可见的下降。
   - 注意：非常适合高分辨率截图以及细节要求不高的任务。

4. **记忆模式切换** — 每个助手可独立选择**自动注入**（每次对话自动注入记忆到系统提示词）或**按需工具**（通过 `read_memory` 工具按需读取记忆）。工具模式保持系统提示词稳定，极大降低 API 缓存未命中率，减少响应延迟。
   - *提示*：为获得最佳缓存性能，建议关闭"最近对话参考"并切换到按需记忆模式。

5. **工具提示词优化** — 重写了内置工具的描述，使其更加简洁精准，帮助模型更稳定地选对工具，并减少输出格式错误。

6. **SVG 预览** — 在 `svg` 代码块内联渲染 SVG 图表。

7. **仓库其他修复项**
   - OCR 结果缓存重启后不再丢失（SQLite 持久化）
   - `fetch_markdown` 工具输出现会清理 `<script>` 和 `<style>` 标签，减少不必要的 token 消耗
   - Qwen / Doubao 模型能力探测
   - Gemini 缓存 Token 的准确统计
   - 优化标题生成逻辑（首次失败自动重试）
   - 其他多项稳定性改进


## 注意事项

Cuplivo 是一个社区分支，尚未与原项目完全切割。赞赏码和社区群组（Discord、QQ）仍指向原作者。过渡期间部分地方可能存在名称混用。

---

<div align="center">
  <img src="docx/screenshot_1.png" alt="聊天界面" width="150" />
  <img src="docx/screenshot_2.png" alt="模型选择" width="150" />
  <img src="docx/screenshot_3.png" alt="工具调用" width="150" />
  <img src="docx/screenshot_4.png" alt="网络搜索" width="150" />
</div>

## 🚀 下载

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/kelivo/id6752122930)


🔗 [下载最新版本](https://github.com/Chevey339/kelivo/releases/latest)

🔗 [TestFlight](https://testflight.apple.com/join/erbGGykR) 参与测试版体验。

## 💖 赞助

感谢 [siliconflow.cn](https://siliconflow.cn) 与我们合作提供可免费使用的模型。

## ✨ 功能特性

- 🎨 **现代化设计** - Material You 设计语言，支持动态主题色(Android12+)
- 🌙 **深色模式** - 完美适配深色主题，保护您的眼睛
- 🌍 **多语言支持** - 支持中文和英文界面
- 🖥️ **多平台支持** - 移动端与桌面端均支持（Android/iOS/Harmony、Windows/macOS/Linux）
- 🔄 **多供应商支持** - 支持 OpenAI、Google Gemini、Anthropic 等主流 AI 供应商
- 🤖 **自定义助手** - 创建和管理个性化 AI 助手
- 🖼️ **多模态输入** - 支持图片、文本文档、PDF、Word 文档等多种格式
- 📝 **Markdown 渲染** - 完整支持代码高亮、LaTeX 公式、表格等
- 🎙️ **语音服务** - 内置系统 TTS，同时支持 OpenAI / Google Gemini / ElevenLabs 语音服务器
- 🛠️ **MCP 支持** - Model Context Protocol 工具集成
- 🧰 **内置 MCP 工具** - 内置 fetch MCP 工具
- 🔍 **网络搜索** - 集成多种搜索引擎（Bing、DuckDuckGo、Exa、Tavily、智谱、LinkUp、Brave、Metaso、SearXNG、Ollama、Jina、Perplexity、Bocha、Serper、Grok）
- 🧩 **提示词变量** - 支持模型名称、时间等动态变量
- 📤 **二维码分享** - 通过二维码导出和导入供应商配置
- 💾 **数据备份** - 支持聊天记录备份和恢复
- 🌐 **自定义请求** - 支持自定义 HTTP 请求头和请求体
- 🔡 **自定义字体** - 支持自定义字体（系统字体 / Google Fonts）
- ⚙️ **Android 后台生成对话** - 可在后台持续生成消息（可在设置中开启）。

## 📱 平台支持

- ✅ Android
- ✅ iOS
- ✅ Harmony ([kelivo-ohos](https://github.com/Chevey339/kelivo-ohos))
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🤝 贡献指南

欢迎提交 Pull Request 或创建 Issue！

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

## ❤️ 致谢

特别感谢 [RikkaHub](https://github.com/re-ovo/rikkahub) 项目提供的 UI 设计灵感。Kelivo 的界面设计深受 RikkaHub 优美且实用的设计启发。

## ⭐ Star History

如果你喜欢这个项目，可以给个Star ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=Chevey339/kelivo&type=Date)](https://star-history.com/#Chevey339/kelivo&Date)

## 📄 许可证

本项目采用 AGPL-3.0 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 联系我们

- Issue: [GitHub Issues](https://github.com/Chevey339/kelivo/issues)

---

<div align="center">
Made with ❤️ using Flutter
</div>
