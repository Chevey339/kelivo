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

输出只包含平台、ABI、SQLite 元数据和布尔/数值能力，不包含消息正文、秘密或完整文件路径。

## 2. 实际命令

```bash
flutter test integration_test/database_platform_capabilities_test.dart -d macos
flutter test integration_test/database_platform_capabilities_test.dart \
  -d 23F16745-F0FE-4BD5-A5CC-23B386B06966
```

## 3. 当前证据

| 平台 | 目标 | ABI | SQLite | 结果 | 边界 |
| --- | --- | --- | --- | --- | --- |
| macOS | macOS 26.5.2 / M4 Pro | `macos_arm64` | 3.53.2 / 3053002 | `PASS` | 当前真实主机进程 |
| iOS | iPhone 17 / iOS 26.5 simulator | `ios_arm64` | 3.53.2 / 3053002 | `PASS` | Apple Silicon 模拟器，不等于物理设备断电/文件系统证据 |
| Android | — | — | — | `BLOCKED` | 当前无设备或已安装 system image；只有 SDK/emulator 工具链 |
| Windows | — | — | — | `BLOCKED` | 当前 macOS 主机无 Windows runner |
| Linux | — | — | — | `BLOCKED` | 当前 macOS 主机无 Linux runner |

macOS 与 iOS 的机器可读结果一致：

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

## 4. 构建发现

Flutter 3.44 首次尝试自动接入实验性 Swift Package Manager 时，iOS 既有插件对 `TOCropViewController` 的版本范围冲突，测试尚未进入应用进程。项目已在 `pubspec.yaml` 显式保持 CocoaPods；随后同一 iOS runner 构建并通过。该设置不升级或替换插件依赖。

## 5. 未覆盖边界

- Android、Windows、Linux 尚无当前提交的运行证据，DB2-07 不得标记完成。
- iOS 仅模拟器；未覆盖物理设备、后台终止或断电。
- 文件锁证据覆盖同进程 API 获取/释放和两个 SQLite connection 的写锁冲突；不外推为五平台跨进程锁语义。
- full barrier/rename 证明平台 adapter 调用在测试中成功返回；不证明 raw syscall 内部窗口或硬件断电。
- 进程强杀、timeline profile、安全存储属于方案 §13.2 更大的五平台发布门禁，不能由本 capability runner 代替。
