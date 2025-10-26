# GitHub Secrets 配置说明

在推送代码并触发 GitHub Actions 构建之前，需要在 GitHub 仓库中配置以下 Secrets：

## 配置步骤

1. 打开你的 GitHub 仓库：https://github.com/KianaMei/kelivo
2. 点击 **Settings** (设置)
3. 在左侧菜单中找到 **Secrets and variables** → **Actions**
4. 点击 **New repository secret** 按钮

## 需要添加的 Secrets

### 1. KEYSTORE_BASE64
**名称**: `KEYSTORE_BASE64`
**值**: 复制 `android/app/upload-keystore.jks.base64` 文件的全部内容（包括 BEGIN 和 END 行）

### 2. KEYSTORE_PASSWORD
**名称**: `KEYSTORE_PASSWORD`
**值**: `kelivo2024`

### 3. KEY_PASSWORD
**名称**: `KEY_PASSWORD`
**值**: `kelivo2024`

### 4. KEY_ALIAS
**名称**: `KEY_ALIAS`
**值**: `upload`

## 完成后

配置完成后，就可以推送代码并打标签触发构建了：

```bash
git add .
git commit -m "配置 Android 签名和 v1.1.0 发布"
git tag v1.1.0
git push origin master
git push origin v1.1.0
```

## 注意事项

- **不要将 `upload-keystore.jks` 和 `key.properties` 提交到 Git**（已添加到 .gitignore）
- 密钥文件和密码要妥善保管
- 如果需要更改密码，记得同时更新 GitHub Secrets 和本地的 `key.properties` 文件

