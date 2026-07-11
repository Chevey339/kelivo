# DB2-07 SQLite 平台能力证据（2026-07-11）

## 1. 验证合同

统一 runner：`integration_test/database_platform_capabilities_test.dart`

每个平台必须在目标进程内实际执行：

- 空库 schema v2 → v3 migration 与完整性复验；
- SQLite FTS5 + `unicode61`；
- WAL 与 `synchronous=FULL` 实际回读；
- SQLite Online Backup API，并回读 snapshot 与 `integrity_check`；
- 两连接写锁冲突、Dart 文件锁 API；
- 平台 full file/directory barrier 与 rename；
- SQLite version/source ID 和 Dart target ABI 输出。

DB2-08 接入 live connection contract 后，macOS/iOS 两个目标均再次运行通过；runner 会在 migration 后通过 repository 断言 live Drift 连接实际为 WAL、FK ON、busy timeout 5000ms、FULL、auto-checkpoint 1000 pages 与 journal size limit 16 MiB，而不只验证独立 raw sqlite handle。

输出只包含平台、ABI、SQLite 元数据和布尔/数值能力，不包含消息正文、秘密或完整文件路径。

## 2. 实际命令

```bash
flutter test integration_test/database_platform_capabilities_test.dart -d macos
flutter test integration_test/database_platform_capabilities_test.dart \
  -d 23F16745-F0FE-4BD5-A5CC-23B386B06966
flutter test integration_test/database_platform_capabilities_test.dart \
  -d fee8c1be
flutter test integration_test/database_platform_capabilities_test.dart -d windows
flutter test integration_test/database_platform_capabilities_test.dart -d linux
```

## 3. 当前证据

| 平台 | 目标 | ABI | SQLite | 结果 | 边界 |
| --- | --- | --- | --- | --- | --- |
| macOS | macOS 26.5.2 / M4 Pro | `macos_arm64` | 3.53.2 / 3053002 | `PASS` | 当前真实主机进程 |
| iOS | iPhone 17 / iOS 26.5 simulator | `ios_arm64` | 3.53.2 / 3053002 | `PASS` | Apple Silicon 模拟器，不等于物理设备断电/文件系统证据 |
| Android | 2112123AC / Android 11 (API 30) | `android_arm64` | 3.53.2 / 3053002 | `PASS` | USB 连接的 arm64 物理设备；系统 build `RKQ1.200826.002 test-keys` |
| Windows | 用户侧 Windows 原生环境 | 未回传 | 未回传 | `PASS` | 用户确认同一 runner 完整通过；结构化结果未复制到当前线程/仓库 |
| Linux | 用户侧 Linux 原生环境 | 未回传 | 未回传 | `PASS` | 用户确认同一 runner 完整通过；结构化结果未复制到当前线程/仓库 |

macOS、iOS 与 Android 的机器可读能力结果一致：

- `schemaVersion=3`
- `fts5=true`
- `unicode61=true`
- `onlineBackup=true`
- `sqliteLockContention=true`
- `journalMode=wal`
- `synchronous=2`（FULL）
- `fileLock=true`
- `fullBarrierRename=true`
- SQLite source ID：`2026-06-03 19:12:13 d6e03d8c777cfa2d35e3b60d8ec3e0187f3e9f99d8e2ee9cac695fd6fcdf1a24`

`unicode61` 对完整中文 token `中文测试` 可命中，但查询短串 `中文` 的结果为 0。该事实不在 DB2-07 中静默 fallback；短中文搜索策略继续由 OPS-04 实现和验收。

Windows 与 Linux 由用户在各自原生环境执行同一 runner，并确认均通过，因此 DB2-07 五平台 capability gate 记为 5/5。由于两次 `DB2_CAPABILITY_RESULT` 原始行未回传，报告不猜测其设备、ABI、SQLite version/source ID 或短中文命中数；这些精确元数据仍应在后续五平台发布门禁中归档。

## 4. 构建发现

Flutter 3.44 首次尝试自动接入实验性 Swift Package Manager 时，iOS 既有插件对 `TOCropViewController` 的版本范围冲突，测试尚未进入应用进程。项目已在 `pubspec.yaml` 显式保持 CocoaPods；随后同一 iOS runner 构建并通过。该设置不升级或替换插件依赖。

Android 首次构建发现应用固定 NDK 27.0.12077973，而 Flutter 3.44 的 `integration_test` 与 `jni` 要求 NDK 28.2.13676358。Android app 已切换到向后兼容的较高版本；随后 debug APK 构建、安装和 runner 均在物理设备通过。构建时仍有一组旧插件使用 Kotlin Gradle Plugin 的未来兼容性警告，不影响本次能力断言，后续依赖升级需单独处理。

## 5. 未覆盖边界

- Windows/Linux 本轮只有用户侧 PASS 确认，未归档结构化结果和机器信息；不能用于比较 SQLite ABI/version/source ID 或短中文命中数。
- iOS 仅模拟器；未覆盖物理设备、后台终止或断电。
- 文件锁证据覆盖同进程 API 获取/释放和两个 SQLite connection 的写锁冲突；不外推为五平台跨进程锁语义。
- full barrier/rename 证明平台 adapter 调用在测试中成功返回；不证明 raw syscall 内部窗口或硬件断电。
- 进程强杀、timeline profile、安全存储属于方案 §13.2 更大的五平台发布门禁，不能由本 capability runner 代替。
