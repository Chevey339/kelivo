---
name: firefox-addon-dev
description: Firefox WebExtensions 插件开发完整指南 — 桌面/安卓/API/调试/发布
version: 1.0.0
author: ChatGPT
trigger: [火狐, firefox, 插件, 扩展, addon, extension, webextension, 浏览器扩展, 自制扩展, xpi, about:debugging, 签名, manifest.json, 安卓扩展, firefox nightly]
priority: 90
---

# Firefox WebExtensions 插件开发指南

官方文档: https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions

---

## 一、最小插件结构

```
my-extension/
├── manifest.json       # 插件清单（必须）
├── background.js       # 后台脚本（Service Worker 风格）
├── content.js          # 内容脚本（注入页面）
├── popup.html          # 弹窗 UI（⚠️ 安卓不支持 popup）
└── popup.js            # 弹窗逻辑
```

打包为 `.xpi`（本质是 zip）：
```bash
cd my-extension && zip -r ../my-extension.xpi *
```

---

## 二、manifest.json

```json
{
  "manifest_version": 2,
  "name": "我的插件",
  "version": "1.0.0",
  "description": "插件描述",
  "author": "Your Name",

  "browser_action": {
    "default_title": "点击打开",
    "default_popup": "popup.html",
    "default_icon": {
      "16": "icons/icon-16.png",
      "48": "icons/icon-48.png",
      "128": "icons/icon-128.png"
    }
  },

  "background": {
    "scripts": ["background.js"],
    "persistent": false
  },

  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"],
      "css": ["style.css"]
    }
  ],

  "permissions": [
    "tabs",
    "storage",
    "webRequest",
    "<all_urls>"
  ],

  "applications": {
    "gecko": {
      "id": "my-extension@example.com",
      "strict_min_version": "57.0"
    }
  },

  "icons": {
    "48": "icons/icon-48.png",
    "96": "icons/icon-96.png"
  }
}
```

### manifest_version 3（MV3）

Firefox 已支持 MV3，但 MV2 仍长期可用。MV3 主要变化：
- `background.scripts` → `background.service_worker`
- `browser_action` → `action`
- 使用 `host_permissions` 替代 `permissions` 中的 URL 模式

```json
{
  "manifest_version": 3,
  "name": "我的插件 (MV3)",
  "version": "1.0.0",
  "action": {
    "default_popup": "popup.html"
  },
  "background": {
    "type": "module",
    "scripts": ["background.js"]
  },
  "host_permissions": ["<all_urls>"],
  "permissions": ["tabs", "storage"],
  "browser_specific_settings": {
    "gecko": {
      "id": "my-ext@example.com",
      "strict_min_version": "109.0"
    }
  }
}
```

---

## 三、常用 API

### Tabs API
```javascript
// 获取当前活跃标签
const [tab] = await browser.tabs.query({ active: true, currentWindow: true });

// 创建标签
browser.tabs.create({ url: "https://example.com" });

// 更新标签 URL
browser.tabs.update(tabId, { url: "https://example.com" });

// 在标签页中执行脚本
await browser.tabs.executeScript(tabId, {
  code: 'document.body.style.backgroundColor = "red"'
});

// 监听标签切换
browser.tabs.onActivated.addListener(({ tabId }) => {});
```

### Runtime API
```javascript
// 获取插件 URL（指向插件内资源）
const url = browser.runtime.getURL("icons/icon.png");

// 发送消息到 content script
browser.tabs.sendMessage(tabId, { type: "hello" });

// 监听消息
browser.runtime.onMessage.addListener((message, sender) => {
  if (message.type === "hello") {
    return { response: "Hi from background!" };
  }
});

// 打开选项页
browser.runtime.openOptionsPage();

// 获取插件信息
const { id, version, name } = browser.runtime.getManifest();
```

### Storage API
```javascript
// 存储
await browser.storage.local.set({ key: "value" });

// 读取
const { key } = await browser.storage.local.get("key");

// 删除
await browser.storage.local.remove("key");

// 清空
await browser.storage.local.clear();

// 监听变化
browser.storage.onChanged.addListener((changes, area) => {
  for (const [key, { oldValue, newValue }] of Object.entries(changes)) {
    console.log(`${key} changed from ${oldValue} to ${newValue}`);
  }
});
```

### webRequest API
```javascript
// 拦截请求
browser.webRequest.onBeforeRequest.addListener(
  (details) => {
    console.log("请求:", details.url);
    return { cancel: false }; // 或 { redirectUrl: "..." }
  },
  { urls: ["<all_urls>"] },
  ["blocking"]
);

// 修改请求头
browser.webRequest.onBeforeSendHeaders.addListener(
  (details) => {
    details.requestHeaders.push({ name: "X-Custom", value: "Hello" });
    return { requestHeaders: details.requestHeaders };
  },
  { urls: ["<all_urls>"] },
  ["blocking", "requestHeaders"]
);
```

### 其他常用 API
| API | 用途 |
|-----|------|
| `browser.windows` | 窗口管理 |
| `browser.bookmarks` | 书签操作 |
| `browser.downloads` | 下载管理 |
| `browser.notifications` | 系统通知 |
| `browser.alarms` | 定时任务 |
| `browser.contextMenus` | 右键菜单 |
| `browser.commands` | 快捷键（manifest 中声明） |
| `browser.i18n` | 国际化 |

---

## 四、开发调试

### 临时加载扩展（开发调试）

**桌面版：**
1. 地址栏打开 `about:debugging#/runtime/this-firefox`
2. 点击 **「Load Temporary Add-on…」**
3. 选择 `manifest.json` 或 `.xpi` 文件
4. ✅ 每次修改代码后点击 **「Reload」** 即可更新

**安卓版（远程调试）：**
1. 手机端 `about:config` → 设以下为 `true`：
   - `devtools.debugger.remote-enabled`
   - `devtools.debugger.remote-wifi`
   - `devtools.chrome.enabled`
2. 电脑 Firefox → `about:debugging#/setup` → USB 连接
3. 连接后选择手机设备 → **「Inspect」** → **「Temporary Extensions」**

### console 调试
```javascript
// background.js / popup.js 中直接使用
console.log("调试信息");
console.error("错误信息");
```

右键扩展图标 → **「检查扩展」** 打开浏览器工具箱查看控制台。

### web-ext CLI 命令行工具
```bash
# 安装
npm install --global web-ext

# 自动加载并监听文件变化（开发模式）
web-ext run --firefox=firefox-nightly

# 在安卓设备上运行
web-ext run --target=firefox-android --firefox-apk=org.mozilla.fenix

# 构建
web-ext build

# 签名
web-ext sign --api-key=... --api-secret=...

# Lint 检查
web-ext lint
```

### 常用 about:config 调试配置
| 配置项 | 值 | 说明 |
|--------|-----|------|
| `xpinstall.signatures.required` | `false` | 关闭签名验证（安装未签名扩展） |
| `extensions.experiments.enabled` | `true` | 允许实验性 API |
| `devtools.chrome.enabled` | `true` | 启用浏览器工具箱 |
| `extensions.legacy.enabled` | `true` | 允许旧版扩展（Nightly 专用） |
| `extensions.langpacks.signatures.required` | `false` | 关闭语言包签名验证 |

---

## 五、Android 适配要点

Firefox for Android 与桌面版的扩展 API 存在差异：

| API/功能 | Android 支持情况 |
|----------|-----------------|
| `browser_action` (popup) | ❌ 不支持弹窗 |
| `page_action` | ✅ 支持 |
| `background` 脚本 | ✅ 支持 |
| `content_scripts` | ✅ 支持 |
| `storage` | ✅ 支持 |
| `tabs` | ✅ 支持 |
| `webRequest` | ✅ 支持 |
| `contextMenus` | ✅ 支持 |
| 侧边栏 API | ❌ 不支持 |
| 开发者工具面板 | ❌ 不支持 |
| `browserAction.onClicked` | ✅ 可用（替代 popup） |

### Android 适配方案

不依赖 popup 的扩展写法：
```javascript
// manifest.json — 不设 default_popup
{
  "browser_action": {
    "default_title": "点击执行",
    "default_area": "navbar"
  },
  "background": {
    "scripts": ["background.js"],
    "persistent": false
  }
}

// background.js — 通过 onClicked 代替 popup
browser.browserAction.onClicked.addListener(async (tab) => {
  // 在标签页中注入 UI / 执行操作
  await browser.tabs.executeScript(tab.id, {
    code: `showMyPanel()`
  });
});
```

---

## 六、Firefox Nightly 安卓版安装自制扩展

### 方法一：关签名 + 本地 .xpi 安装（推荐）

1. `about:config` → `xpinstall.signatures.required` → **false**
2. 将 `.xpi` 放到手机 `/sdcard/Download/`
3. 地址栏输入 `file:///sdcard/Download/你的扩展.xpi` → 确认安装

### 方法二：文件管理器直接打开

1. 同上，关签名验证
2. 用文件管理器找到 `.xpi` → 长按 → 打开方式 → Firefox Nightly

### 方法三：远程调试临时加载（开发用）

见上方「安卓版（远程调试）」章节，适合开发阶段反复修改。

---

## 七、Chrome 兼容

### 差异对照

| 特性 | Firefox | Chrome |
|------|---------|--------|
| API 前缀 | `browser.*`（异步 Promise） | `chrome.*`（回调） |
| manifest 标识 | `applications.gecko.id` | 无 |
| contentScript 配置 | 支持 `manifest.json` 和 `about:config` | 仅 `manifest.json` |
| 文件访问 | 默认可访问本地文件 | 需勾选 "允许访问文件网址" |

### 跨浏览器兼容写法

使用 **webextension-polyfill**：
```bash
npm install webextension-polyfill
```

```javascript
import browser from 'webextension-polyfill';

// 统一使用 browser.* API
const [tab] = await browser.tabs.query({ active: true });
```

或手动兼容：
```javascript
window.browser = window.browser || window.chrome;
```

---

## 八、发布到 AMO

### 手动发布
1. 登录 [addons.mozilla.org](https://addons.mozilla.org/)
2. 开发者中心 → **「提交新插件」**
3. 上传 `.xpi` 文件
4. 填写描述、分类、截图
5. 提交审核（首次需人工审核，更新自动审核）

### web-ext 自动签名
```bash
# 获取 API 密钥：https://addons.mozilla.org/developers/addon/api/key/
web-ext sign \
  --api-key=user:12345678 \
  --api-secret=your-secret-key
```

### 发布检查清单
- [ ] 插件 ID 格式正确（`name@example.com`）
- [ ] 所有权限都有正当理由
- [ ] 代码无混淆/无远程脚本（AMO 禁止）
- [ ] 有隐私政策（如需收集数据）
- [ ] 图标尺寸齐全（48px / 96px）

---

## 九、推荐学习资源

| 资源 | URL |
|------|-----|
| MDN WebExtensions 总文档 | https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions |
| API Reference | https://developer.mozilla.org/docs/Mozilla/Add-ons/WebExtensions/API |
| 入门教程 | https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Your_first_WebExtension |
| manifest.json 文档 | https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json |
| web-ext CLI | https://extensionworkshop.com/documentation/develop/getting-started-with-web-ext/ |
| AMO 发布指南 | https://extensionworkshop.com/documentation/publish/ |
| Chrome 与 Firefox 差异 | https://extensionworkshop.com/documentation/develop/differences-between-desktop-and-android-extensions/ |
| 安卓扩展开发 | https://extensionworkshop.com/documentation/develop/developing-extensions-for-firefox-for-android/ |

---

## 十、快速开发模板

### background.js（最简后台）
```javascript
// 安装或更新时的操作
browser.runtime.onInstalled.addListener(({ reason }) => {
  if (reason === "install") {
    browser.storage.local.set({ welcome: true });
  }
});

// 监听浏览器按钮点击
browser.browserAction.onClicked.addListener((tab) => {
  browser.tabs.sendMessage(tab.id, { type: "toggle" });
});

// 定时任务
browser.alarms.create("check-updates", { periodInMinutes: 60 });
browser.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "check-updates") {
    console.log("定时检查更新...");
    // doSomething()
  }
});
```

### content.js（最简内容脚本）
```javascript
// 监听来自 background 的消息
browser.runtime.onMessage.addListener((message) => {
  if (message.type === "toggle") {
    const panel = document.getElementById("my-panel");
    if (panel) {
      panel.remove();
    } else {
      const div = document.createElement("div");
      div.id = "my-panel";
      div.textContent = "Hello from extension!";
      div.style.cssText = "position:fixed;top:0;right:0;z-index:9999;background:white;border:1px solid #ccc;padding:16px;";
      document.body.appendChild(div);
    }
  }
});
```

---

## 十一、常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 安装提示"损坏" | 签名验证未关闭 | `xpinstall.signatures.required = false` |
| 扩展不生效 | 权限未声明 | 检查 `permissions` 是否正确 |
| 安卓上按钮不显示 | 用了 popup | 改用 `browserAction.onClicked` |
| 重启后扩展消失 | 用了临时加载 | 关闭签名后通过文件安装 `.xpi` |
| 提示"不兼容" | `strict_min_version` 太高 | 降低版本号或去掉该字段 |
| API 报错 | API 不支持当前版本 | 检查 MDN 文档的浏览器兼容性表格 |