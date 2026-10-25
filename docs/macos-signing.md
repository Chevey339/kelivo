# macOS 签名、公证与 Homebrew

发布 workflow 的 macOS job 会在 secrets 配齐时，用 **Developer ID Application** 签名 `kelivo.app` 和 DMG，再用 `notarytool` 公证并 staple。secrets 全部未配置时（fork、PR、还没准备证书），job 仍构建未签名 DMG，并且成功结束。

个人 Apple Developer 账号，Team ID：`5WN7Y88J52`。

签名脚本是 `tool/macos_sign_and_notarize.sh`。下面四个 workflow 的 macOS job 都会调用它，Windows / Linux / Android / iOS job 没有改动：

- `.github/workflows/build.yml`（Flutter master）
- `.github/workflows/build-stable.yml`
- `.github/workflows/build-stable-44.yml`
- `.github/workflows/build-stable-47.yml`

用平时发版的那个 workflow，勾选构建 macOS。要上传到 GitHub Release 时再勾选发布并填写 tag（现有 tag 形如 `v1.3.1`）。公证失败时不会执行发布步骤。

只在本仓库的可信分支上手动触发带签名的构建。不要在来自 fork、并且改过 workflow 的分支上运行，否则修改后的脚本可以读到这些 secrets。

## 要创建的 GitHub Actions secrets

在仓库 **Settings → Secrets and variables → Actions → Repository secrets** 里新建。不要把证书或密钥提交进 git，也不要放到 Codespaces / Dependabot secrets。

签名必须两组都有：**证书**，以及 **一种公证凭据**。推荐 App Store Connect API 密钥。API 密钥和 Apple ID 都配齐时，使用 API 密钥。

只填了一半（例如只有证书、没有公证，或 API 三项缺一项）时，macOS job 会失败并说明缺什么。还没准备好时，把相关 secret 留空，构建会按未签名成功。

| Secret | 何时需要 | 内容 |
| --- | --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | 签名 | Developer ID Application `.p12` 的 base64 |
| `MACOS_CERTIFICATE_PASSWORD` | 签名 | 导出 `.p12` 时设置的密码 |
| `APP_STORE_CONNECT_API_KEY_ID` | 公证（推荐） | API 密钥的 Key ID，10 位 |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | 公证（推荐） | 密钥页顶部的 Issuer ID（UUID） |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | 公证（推荐） | `AuthKey_XXXX.p8` 的 base64 |
| `APPLE_ID` | 公证（备选） | 能管理该 Team 的 Apple ID 邮箱 |
| `APPLE_APP_SPECIFIC_PASSWORD` | 公证（备选） | 该 Apple ID 的 App 专用密码 |
| `APPLE_TEAM_ID` | 可选 | 默认 `5WN7Y88J52`。只有换 Team 时才建这个 secret |

`APP_STORE_CONNECT_API_KEY_ISSUER_ID` 不是 Team ID。Team ID 是 `5WN7Y88J52`，Issuer ID 是密钥页面上的 UUID。

## 导出 Developer ID Application 证书

个人账号只有 Account Holder 能创建 Developer ID 证书。在 Mac 上操作。

1. 打开「钥匙串访问」→ 菜单「证书助理」→「从证书颁发机构请求证书…」。
2. 填入 Apple ID 邮箱。常用名称可写 `Kelivo Developer ID`。选择「存储到磁盘」。CA 邮箱留空。得到 `CertificateSigningRequest.certSigningRequest`。
3. 打开 [Certificates](https://developer.apple.com/account/resources/certificates/list)，确认右上角 Team 是 `5WN7Y88J52`，点 **+**。
4. 选择 **Developer ID Application**（说明是在 Mac App Store 之外分发应用）。不要选：
   - Apple Development
   - Apple Distribution / Mac App Distribution
   - Mac Installer Distribution
   - **Developer ID Installer**（那是给 `.pkg` 用的；Kelivo 发布的是 `.dmg`）
5. 上传上一步的 CSR，下载 `.cer`，双击装进「登录」钥匙串。
6. 在「登录」→「我的证书」里展开 **Developer ID Application: 名字 (5WN7Y88J52)**，下面必须挂着私钥。若证书在「系统」钥匙串、私钥在另一串，导出的 `.p12` 不能用来签名。
7. 选中该证书（连同它的私钥），右键「导出…」，格式选 **个人信息交换 (.p12)**，设置密码。这个密码就是 `MACOS_CERTIFICATE_PASSWORD`。
8. 在 Mac 上生成 base64，粘贴到 `MACOS_CERTIFICATE_P12_BASE64`：

```bash
base64 -i /path/to/certificate.p12 | tr -d '\n' | pbcopy
```

CI 会把证书导入临时钥匙串，签完即删除。中间证书（Developer ID Certification Authority G2）会在 runner 上另行下载；`.p12` 里保留叶子证书和私钥即可。

## App Store Connect API 密钥（推荐）

1. 用 Account Holder 或 Admin 打开 [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)。
2. 选 **Team Keys**，Generate API Key。名称例如 `Kelivo notarization`。访问权限选 **Developer**（公证需要这个角色）。
3. 下载 `AuthKey_XXXXXXXXXX.p8`。这个文件只能下载一次。
4. **Key ID** 是密钥那一行的 10 位 ID，填入 `APP_STORE_CONNECT_API_KEY_ID`。
5. 页面上方的 **Issuer ID**（UUID）填入 `APP_STORE_CONNECT_API_KEY_ISSUER_ID`。
6. 生成 base64：

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy
```

粘贴到 `APP_STORE_CONNECT_API_KEY_P8_BASE64`。

## 备选：Apple ID 与 App 专用密码

API 密钥不可用时再使用这条路径。Apple ID 必须能访问 Team `5WN7Y88J52` 的 Developer ID。

1. 打开 [appleid.apple.com](https://appleid.apple.com) → 登录与安全 → **App 专用密码**，生成一个密码。
2. `APPLE_ID` 填邮箱。`APPLE_APP_SPECIFIC_PASSWORD` 填专用密码（形如 `xxxx-xxxx-xxxx-xxxx`），不要填 Apple ID 登录密码。
3. 一般不用创建 `APPLE_TEAM_ID`。脚本默认使用 `5WN7Y88J52`。

## 签名做了什么

`flutter build macos --release` 之后：

1. 把 `.p12` 导入临时钥匙串，选出名称里带 Team ID 的 **Developer ID Application** 身份。
2. 由内向外签名 `.app`：先签嵌套的 Mach-O / `.dylib`，再签 `.framework`、`.bundle`、helper，最后用 Hardened Runtime、secure timestamp 和 `macos/Runner/Release.entitlements` 签主应用。不用 `codesign --deep` 来签名（它会漏掉嵌套二进制）；`--deep` 只用于校验。
3. 打 DMG。若 `create-dmg` 破坏了包内签名，脚本会改用 `hdiutil` 从已签名的 `.app` 重新打包。
4. 用同一个 Developer ID 给 DMG 加 timestamp 签名。
5. `xcrun notarytool submit --wait` 提交 DMG。被拒绝时，日志里会打出 Apple 的 notarization log。
6. `xcrun stapler staple` 把票据钉到 DMG 上。
7. 挂载 DMG，对里面的 `kelivo.app` 运行 `codesign --verify --deep --strict` 和 `spctl --assess --type execute`，并对 DMG 运行 `spctl --assess --type open`。

`Release.entitlements` 增加了 `com.apple.security.cs.allow-jit`。Hardened Runtime 下，Flutter 引擎和内置 WKWebView 都需要它，否则公证后的应用会在启动或打开网页时被系统杀掉。应用没有启用 App Sandbox，这次也没有打开 Sandbox。

本地抽查已发布的 DMG：

```bash
hdiutil attach Kelivo_macos_1.3.1+80.dmg
codesign --verify --deep --strict --verbose=2 /Volumes/Kelivo/kelivo.app
codesign --display --verbose=4 /Volumes/Kelivo/kelivo.app
spctl --assess --type execute --verbose=4 /Volumes/Kelivo/kelivo.app
spctl --assess --type open --context context:primary-signature --verbose=4 Kelivo_macos_1.3.1+80.dmg
xcrun stapler validate Kelivo_macos_1.3.1+80.dmg
```

通过时 `spctl` 的来源是 `Notarized Developer ID`。

## 提交到官方 Homebrew Cask

官方 cask 要求应用用 Developer ID 签名并完成公证。仓库里还没有这样的 release，所以 **不要现在提交**。社区 tap 里已有一份未签名版本的 cask：<https://github.com/AkinoKaede/homebrew-kuchikamizake/blob/main/Casks/kelivo.rb>。

第一次签过名的 release 发出后：

1. 确认发布 tag 是 `v<版本号>`（例如 `v1.3.1`），资源名是 `Kelivo_macos_<版本号>+<构建号>.dmg`。这和 `pubspec.yaml` 的 `version: 1.3.1+80` 对应。不要拿带 commit SHA 的手动构建产物去交 cask；只有 workflow 里勾选「发布到 Release」时，文件名才不带 SHA。
2. 下载该 DMG，计算哈希：

```bash
shasum -a 256 Kelivo_macos_1.3.1+80.dmg
lipo -archs /Volumes/Kelivo/kelivo.app/Contents/MacOS/kelivo
```

3. 更新 [`docs/homebrew/kelivo.rb`](homebrew/kelivo.rb) 里的 `version` 和 `sha256`。`version "1.3.1,80"` 里逗号前面是版本号、后面是 `+` 后的构建号。若 `lipo` 只有一种架构，加上对应的 `depends_on arch: :arm64` 或 `:x86_64`。
4. 本地检查：

```bash
brew audit --new --cask --online docs/homebrew/kelivo.rb
brew install --cask docs/homebrew/kelivo.rb
spctl --assess --type execute --verbose=4 /Applications/kelivo.app
```

5. Fork [homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask)，把文件放到 `Casks/k/kelivo.rb`，按 [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook) 和 [Adding Software to Homebrew](https://docs.brew.sh/Adding-Software-to-Homebrew) 提 PR。这份草稿不会自动提交。
