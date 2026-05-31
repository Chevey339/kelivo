---
name: obsidian-plugin-dev
description: Obsidian 插件开发 API/UI/编辑器/发布/最佳实践
version: 2.0.0
author: Jaye
trigger: [obsidian, 插件, plugin, 开发, typescript, 构建, 发布, api, 视图, 编辑器, vault, manifest, 命令, 设置, 建议弹窗, 主题, css, esbuild, release]
priority: 95
---

# Obsidian 插件开发指南

官方文档: https://docs.obsidian.md/Home

---

## 一、项目结构

```bash
git clone https://github.com/obsidianmd/obsidian-sample-plugin.git
cd obsidian-sample-plugin && npm install && npm run dev
```

```
my-plugin/
├── manifest.json            # 插件清单（id 不能含 "obsidian"）
├── main.js                  # esbuild 输出 (format:cjs, external:obsidian)
├── styles.css               # ⚡ 手动编写，build 不覆盖！
├── src/main.ts              # 主入口
├── src/settings.ts          # 设置面板
├── esbuild.config.mjs
└── version-bump.mjs
```

```json
// manifest.json
{ "id": "my-plugin", "name": "My Plugin", "version": "1.0.0",
  "minAppVersion": "0.15.0", "description": "...",
  "author": "Name", "isDesktopOnly": false }
```

---

## 二、生命周期

```typescript
import { Plugin } from 'obsidian';
export default class MyPlugin extends Plugin {
  async onload() {
    this.registerView(VIEW_TYPE, (leaf) => new MyView(leaf));
    this.addCommand({ id: 'cmd', name: 'Cmd', callback: () => {} });
    this.addRibbonIcon('dice', '提示', () => new Notice('Hi'));
    this.addSettingTab(new MySettingTab(this.app, this));
    this.registerEvent(this.app.vault.on('create', () => {}));
    this.registerInterval(window.setInterval(() => {}, 1000));
    await this.loadSettings();
  }
  async onunload() { this.app.workspace.detachLeavesOfType(VIEW_TYPE); }
  // 数据持久化
  async loadSettings() { this.settings = Object.assign({}, DEFAULTS, await this.loadData()); }
  async saveSettings() { await this.saveData(this.settings); }
}
```

**onload 注册表**: `registerView` · `addCommand` · `addRibbonIcon` · `addSettingTab` · `addStatusBarItem` · `registerEvent` · `registerInterval` · `registerMarkdownPostProcessor` · `registerMarkdownCodeBlockProcessor`

---

## 三、核心 API

```typescript
// Vault
vault.getMarkdownFiles() | vault.getFiles() | vault.read(file) | vault.cachedRead(file)
vault.modify(file, content) | vault.create(path, content) | vault.delete(file) | vault.trash(file)
vault.process(file, data => data.replace(':)', '🙂')) // 原子操作

// MetadataCache
const fc = this.app.metadataCache.getFileCache(file);
fc?.frontmatter | fc?.headings | fc?.links | fc?.tags | fc?.blocks
this.app.metadataCache.getFirstLinkpathDest('Note', sourcePath)

// Workspace
workspace.getLeaf(false)  // 复用
workspace.getLeaf(true)   // 新建
workspace.getRightLeaf(false) | workspace.getLeftLeaf(false)
workspace.getLeavesOfType(VIEW_TYPE)
workspace.getActiveViewOfType(MarkdownView)?.editor | ?.file
leaf.openFile(file) | leaf.setViewState({type:VIEW_TYPE, active:true})

// moment（内置）
import { moment } from 'obsidian';
moment().format('YYYY-MM-DD HH:mm');
```

---

## 四、UI 组件

### 自定义视图
```typescript
export const VIEW_TYPE = 'my-view';
export class MyView extends ItemView {
  getViewType()    { return VIEW_TYPE; }
  getDisplayText() { return 'My View'; }
  getIcon()        { return 'book-open-text'; }
  async onOpen()   { this.contentEl.empty(); this.contentEl.createEl('h2', {text:'Hello'}); }
}
this.registerView(VIEW_TYPE, (leaf) => new MyView(leaf));
// 激活: workspace.getLeavesOfType(VIEW_TYPE)[0] ?? workspace.getRightLeaf(false)
```

### 命令
```typescript
this.addCommand({ id: 'cmd', name: 'Cmd', callback: () => {} });
// editorCallback: (editor, view) => editor.replaceSelection(text)
// checkCallback: (checking) => { if(条件) { if(!checking)执行; return true; } return false; }
// hotkeys: [{ modifiers: ['Mod'], key: 'u' }]  // Mod=Ctrl/Cmd
```

### 设置面板
```typescript
class MySettingTab extends PluginSettingTab {
  display() {
    this.containerEl.empty(); // ⚠️ 每次打开都会调用，必须重建！
    new Setting(this.containerEl).setName('Key').setDesc('描述')
      .addText(t => t.setPlaceholder('sk-...').setValue(this.plugin.settings.key)
        .onChange(async v => { this.plugin.settings.key = v; await this.plugin.saveSettings(); }));
  }
}
```
**控件**: `.addText()` `.addTextArea()` `.addToggle()` `.addSlider()` `.addDropdown()` `.addMomentFormat()` `.addColorPicker()` `.addButton()`

### 弹窗 & 建议
```typescript
// FuzzySuggestModal (模糊搜索)
class FileSearcher extends FuzzySuggestModal<TFile> {
  getItems()     { return this.app.vault.getMarkdownFiles(); }
  getItemText(i) { return i.path; }
  onChooseItem(i, _) { /* 选中 */ }
}
new FileSearcher(this.app).open();

// EditorSuggest (编辑器自动补全)
class MentionSuggest extends EditorSuggest<string> {
  onTrigger(cursor, editor) {
    const m = editor.getLine(cursor.line).match(/@(\w*)$/);
    return m ? {start:{line:cursor.line,ch:m.index}, end:{line:cursor.line,ch:m.index+m[0].length}, query:m[1]} : null;
  }
  getSuggestions(ctx)     { return [ctx.query]; }
  renderSuggestion(v, el) { el.createSpan({text:v}); }
  selectSuggestion(v, _)  { this.context?.editor.replaceRange(v, this.context.start, this.context.end); }
}

// 其他
this.addRibbonIcon('dice', '提示', () => new Notice('消息', 5000));
this.addStatusBarItem().setText('Ready');
setIcon(element, 'sun'); // Lucide 图标
```

---

## 五、编辑器 & Front Matter

```typescript
// Editor
const e = this.app.workspace.getActiveViewOfType(MarkdownView)?.editor;
e?.getCursor() | e?.setCursor(l,c) | e?.getSelection() | e?.replaceSelection(text)
e?.replaceRange(text, from, to) | e?.getValue() | e?.setValue(text) | e?.getLine(n)

// Markdown 后处理
this.registerMarkdownPostProcessor((el, ctx) => { el.findAll('code') });
this.registerMarkdownCodeBlockProcessor('csv', (source, el, ctx) => { el.createEl('table'); });

// Front Matter
this.app.fileManager.processFrontMatter(file, (fm) => { fm['tags'] = ['obsidian']; });
const fm = this.app.metadataCache.getFileCache(file)?.frontmatter;
```

---

## 六、事件 & CSS

```typescript
this.registerEvent(this.app.vault.on('create'|'modify'|'delete'|'rename', handler));
this.registerEvent(this.app.metadataCache.on('changed', handler));
this.registerEvent(this.app.workspace.on('file-open', handler));
```

```css
/* 用 --xxx 变量适配深色/浅色，❌ 不写死颜色 */
.my-class {
  background: var(--background-primary);
  color: var(--text-normal);
  border: 1px solid var(--background-modifier-border);
}
```

---

## 七、发布

```yaml
# .github/workflows/release.yml — tag 触发自动发布
on: { push: { tags: ["*"] } }
jobs:
  build:
    runs-on: ubuntu-latest
    permissions: { contents: write }
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with: { node-version: "18" }
      - run: npm install && npm run build
      - run: |
          tag="${GITHUB_REF#refs/tags/}"
          gh release create "$tag" --title="$tag" --draft main.js manifest.json styles.css
```

发布: `git tag -a 1.0.1 -m "1.0.1" && git push origin 1.0.1`

**提交社区**: 向 `obsidianmd/obsidian-releases` 提 PR，加 `community-plugins.json` 条目

---

## 八、最佳实践

```typescript
// 防抖保存
scheduleSave(path, content) {
  clearTimeout(this.timers.get(path));
  this.timers.set(path, window.setTimeout(() => void vault.modify(file, content), 1500));
}
// 防重复请求
fetch(path): Promise<T> {
  if (this.pending.has(path)) return this.pending.get(path)!;
  const p = doFetch().finally(() => this.pending.delete(path));
  return this.pending.set(path, p), p;
}
// 变更抑制
suppress(path, ms=400) { this.suppressed.set(path, Date.now()+ms); }
shouldIgnore(p) { const t=this.suppressed.get(p); return t&&t>Date.now() ? (this.suppressed.delete(p),true) : false; }
```

> ⚠️ `styles.css` 是手动编写的，build 不覆盖但误删无法恢复！改前 `cp styles.css styles.css.bak`

---

## 九、快速模板

```typescript
import { Plugin, PluginSettingTab, Setting, ItemView, Notice } from 'obsidian';
const V = 'hello-view';
interface S { name: string; }
const D: S = { name: 'World' };
export default class P extends Plugin {
  s: S;
  async onload() {
    this.s = Object.assign({}, D, await this.loadData());
    this.registerView(V, l => new class extends ItemView {
      getViewType() { return V; }
      getDisplayText() { return 'Hello'; }
      onOpen() { this.contentEl.empty(); this.contentEl.createEl('h2', {text:`Hi ${(this.app as any).plugins.plugins['p']?.s?.name}`}); }
    }(l));
    this.addCommand({id:'h',name:'Hello',callback:()=>new Notice(`Hi ${this.s.name}`)});
    this.addRibbonIcon('smile','Hello',()=>this.activateView());
    this.addSettingTab(new class extends PluginSettingTab {
      display() {
        this.containerEl.empty();
        new Setting(this.containerEl).setName('Name').addText(t=>t.setValue((this as any).plugin.s.name).onChange(async v=>{(this as any).plugin.s.name=v;await (this as any).plugin.saveSettings();}));
      }
    }(this.app, this));
  }
  async activateView() {
    let l = this.app.workspace.getLeavesOfType(V)[0] ?? this.app.workspace.getRightLeaf(false);
    await l.setViewState({type:V, active:true});
    this.app.workspace.revealLeaf(l);
  }
  onunload() { this.app.workspace.detachLeavesOfType(V); }
}
```

---

## 📚 文档速查

| 内容 | URL |
|------|-----|
| 构建插件 | https://docs.obsidian.md/Plugins/Getting+started/Build+a+plugin |
| UI/视图/命令/设置 | https://docs.obsidian.md/Plugins/User+interface/About+user+interface |
| 编辑器/Markdown后处理 | https://docs.obsidian.md/Plugins/Editor/Editor |
| 事件 | https://docs.obsidian.md/Plugins/Events |
| Vault API | https://docs.obsidian.md/Plugins/Vault |
| 自动发布 | https://docs.obsidian.md/Plugins/Releasing/Release+your+plugin+with+GitHub+Actions |
| CSS 变量 | https://docs.obsidian.md/Reference/CSS+variables/CSS+variables |
| TypeScript API | https://docs.obsidian.md/Reference/TypeScript+API/Reference |