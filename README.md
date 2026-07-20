<div align="center">
  <img src="assets/app_icon.png" alt="Cuplivo Icon" width="100" />
  <h1>Why Cuplivo?</h1>

  A Flutter LLM Chat Client — A community fork
  
  See [Kelivo](https://github.com/Chevey339/kelivo) for community links

  [阅读简体中文文档](README_ZH_CN.md)快速查看特性
</div>

## 🔗 Compatibility

Cuplivo is a community fork of Kelivo with strong compatibility focus:

- **Backup zip format fully compatible.** Configure WebDAV or S3 (or local export/import), restore backup files exported from Kelivo, and pick up where you left off — no reconfiguration needed.
- **Package name changed to avoid conflicts.** Many developers worry that their custom changes will conflict with future Kelivo updates; but installing Cuplivo **does not require uninstalling and will not overwrite** Kelivo — your data is doubly protected.
- **Verified by real users.** Currently known to be used by the author and at least 5 other stable users with no issues reported.
- **UI inherits Kelivo's style.** No major changes overall; existing users will feel right at home.

### 🧪 Stability

This fork is positioned as a **"new feature proving ground"**: it may adopt features the community finds useful, most verified through lightweight self-testing, aiming to provide a more out-of-the-box experience for users seeking the latest capabilities. Basic availability and stability are maintained (no P0 bugs; no data corruption or crash-on-launch bugs encountered so far), but releases are more frequent with lighter review. New features may carry P1/P2-level bugs, though feedback will be addressed promptly.

We are aware that the upstream Kelivo repository is undergoing a major data storage refactoring. In the near term, this fork plans only to maintain compatibility with the new-format `.zip` exports from upstream. Most defensive data-integrity changes made here may not be adopted upstream — **please keep your own backups.**

## ✨ New Features

Unlike most personal-customization or single-feature forks, Cuplivo aims to add multiple features for a broader audience to try out. Some items may be removed as upstream (Kelivo) adds their counterparts.

1. **Incremental backup** — Uploads only conversations, messages and related attachments since a selected date.
   - *In practice*: A 12.6 MB full backup is typically followed by incremental uploads of 50 KB to 1.5 MB. Savings become more apparent as attachments and images accumulate. This reduces bandwidth and storage overhead, encouraging more frequent backups.
   - *Note*: Periodic full snapshots are still recommended.

2. **Proactive care** — AI can proactively send care messages to users on a configurable schedule (Android only).
   - *Android-only*: background alarm + notification channel; alarm persists through force-stop

3. **Multi-AI side-by-side comparison** — Select 2 or more models to answer simultaneously and compare their responses side by side — pick the best result, or synthesize them into a single reply via summary, fusion, or commentary (like a more flexible OpenRouter Fusion).
   - Desktop now shows 2 model responses per page in a two-column layout.
   - *Tip*: Multi-select models in the model picker before sending a message to activate this mode.

4. **Manual image compression** — Phone photos and desktop screenshots are pixel‑sharp but often overkill for LLM tasks.
   - *In practice*: Resizing the long edge from 4096 to 2048 px yields ~425 KB (down from 2.06 MB) and cuts input tokens from 8,136 to 3,096, with no perceptible drop in model response quality.
   - *Note*: Ideal for high-resolution captures and low-detail tasks.

5. **Memory mode switcher** — Per-assistant toggle between **Auto Injection** (memories injected into system prompt on every turn) and **On Demand (Tool)** (memories accessed via `read_memory` tool only when needed). Tool mode keeps the system prompt stable, dramatically improving API cache hit rates and reducing latency.
   - *Tip*: For best cache performance, disable Recent Chats Reference and switch to On Demand mode.

6. **Tool prompt optimization** — Rewrote built-in tool descriptions to be more concise and precise, helping models select the right tool more consistently and minimizing output format errors.

7. **SVG preview** — Renders SVG diagrams inline within `svg` code blocks.

8. **Model capability support** — Adapted for GPT-5.6 (sol/luna/terra) with xhigh/max reasoning effort; added Kimi K3 with max reasoning and both naming variants; broadened Qwen 3.5–3.7 and Doubao seed-2 model family detection for accurate feature availability.

9. **PDF/Office file attachments** — Upload PDF, Word, Excel, and PowerPoint documents directly as attachments, with configurable document processing options.

10. **Additional fixes across the repo**
    - OCR result caching now persists across restarts (SQLite-backed)
    - Accurate Gemini cached-token reporting
    - Optimized title generation logic (auto-retry on first failure)
    - Large base64 images no longer cause regex stack overflow
    - Various other stability improvements

## ⚠️ Note

Cuplivo is a community fork and has not been fully separated from the upstream project. Donation QR codes and community groups (Discord, QQ) still point to the original author. Some references may retain the original name during the transition.

---

<div align="center">
  <img src="docx/screenshot_1.png" alt="Chat Screen" width="150" />
  <img src="docx/screenshot_2.png" alt="Model Selection" width="150" />
  <img src="docx/screenshot_3.png" alt="Tool Calling" width="150" />
  <img src="docx/screenshot_4.png" alt="Web Search" width="150" />
</div>

## 🚀 Download

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/kelivo/id6752122930)

🔗 [Download the latest version](https://github.com/Chevey339/kelivo/releases/latest)

🔗 [TestFlight](https://testflight.apple.com/join/erbGGykR) for beta testing.

## 💖 Sponsors

Thanks to [siliconflow.cn](https://siliconflow.cn) for providing free models in cooperation with us.

## ✨ Features

- 🎨 **Modern Design** - Material You design language with dynamic color theming support (Android 12+).
- 🌙 **Dark Mode** - Perfectly adapted dark theme to protect your eyes.
- 🌍 **Multi-language Support** - Supports both English and Chinese interfaces.
- 🖥️ **Multi-platform Support** - Mobile (Android/iOS/Harmony) and Desktop (Windows/macOS/Linux).
- 🔄 **Multi-provider Support** - Supports major AI providers like OpenAI, Google Gemini, Anthropic, etc.
- 🤖 **Custom Assistants** - Create and manage personalized AI assistants.
- 🖼️ **Multimodal Input** - Supports various formats including images, text documents, PDFs, Word documents, etc.
- 📝 **Markdown Rendering** - Full support for code highlighting, LaTeX formulas, tables, and more.
- 🎙️ **Voice/TTS Providers** - Built-in system TTS plus OpenAI / Google Gemini / ElevenLabs voice servers.
- 🛠️ **MCP Support** - Model Context Protocol tool integration.
- 🧰 **Built-in MCP Tools** - Includes a built-in MCP Fetch tool.
- 🔍 **Web Search** - Integrated with multiple search engines (Bing, DuckDuckGo, Exa, Tavily, Zhipu, LinkUp, Brave, Metaso, SearXNG, Ollama, Jina, Perplexity, Bocha, Serper, Grok).
- 🧩 **Prompt Variables** - Supports dynamic variables like model name, time, etc.
- 📤 **QR Code Sharing** - Export and import provider configurations via QR codes.
- 💾 **Data Backup** - Supports chat history backup and restoration.
- 🌐 **Custom Requests** - Supports custom HTTP request headers and bodies.
- 🔡 **Custom Fonts** - Bring your own fonts (system fonts / Google Fonts).
- ⚙️ **Android Background Generation** - Keep chat generation running in the background (optional setting).

## 📱 Platform Support

- ✅ Android
- ✅ iOS
- ✅ Harmony ([kelivo-ohos](https://github.com/Chevey339/kelivo-ohos))
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🤝 Contribution Guide

Pull Requests and Issues are welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## ❤️ Acknowledgements

Special thanks to the [RikkaHub](https://github.com/re-ovo/rikkahub) project for the UI design inspiration. Kelivo's interface design is heavily inspired by RikkaHub's beautiful and practical design.

## ⭐ Star History

If you like this project, please give it a star ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=Chevey339/kelivo&type=Date)](https://star-history.com/#Chevey339/kelivo&Date)

## 📄 License

This project is licensed under the AGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact Us

- Issue: [GitHub Issues](https://github.com/Chevey339/kelivo/issues)

---

<div align="center">
Made with ❤️ using Flutter
</div>
