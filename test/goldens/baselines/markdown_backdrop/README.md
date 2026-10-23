# Markdown backdrop 像素基线

本目录覆盖 Flutter **3.47.6**（framework `5fc346839b5d0eef006ed8404392afb4dfae428d`，engine `692136cb6582dbfc5af3fb33c2515a069f2f66d0`）下的三个实际验证环境：

| 目录 | Dart ABI | 验证环境 |
| --- | --- | --- |
| `macos_arm64` | `Abi.macosArm64` | macOS 27.0.1 arm64 本机 |
| `linux_arm64` | `Abi.linuxArm64` | OrbStack 中的 Ubuntu arm64 容器 |
| `linux_x64` | `Abi.linuxX64` | OrbStack 中的 Ubuntu 24.04 amd64 仿真容器；不是原生 GitHub CI runner |

每组包含浅色／深色的代码、表格、details 和 diagram，共 8 张图。测试由 `Abi.current()` 选择目录，沿用 Flutter 默认逐像素零容差比较。其他 ABI 明确失败，提示建立新基线。此资产集合的覆盖范围独立于应用支持的平台范围。相同 ABI 仍可能受 SDK、系统和字体环境影响；这里的三组实跑不能保证所有同 ABI 环境像素一致。

原平铺图片缺少生成环境记录；历史提交与当前提交的同环境实际输出一致，而不同 OS／架构的实际输出存在像素差异。本次保留产品渲染和 fixture，使用逐环境审查的实际输出替换来源未知的图片。`manifest.json` 记录每组 SDK、系统、执行方式、源码／fixture／依赖锁及图片 SHA-256。

## 复现与更新

在仓库根目录用 FVM 选择上述 Flutter 版本，再运行：

```sh
fvm flutter pub get
fvm flutter test test/goldens/markdown_backdrop_golden_test.dart --reporter expanded
```

容器验证使用相同版本的 Linux SDK、相同源码和 `pubspec.lock`，并核验 SDK 与测试进程架构；不要挂入 macOS SDK 的二进制缓存。

有意修改视觉结果或新增环境时：

1. 固定 SDK、源码、锁文件、OS 和 ABI；对新 ABI 在测试入口增加明确的目录映射。先运行测试，核实失败是缺失该目录基线或预期的视觉变化。
2. 在目标环境执行同一测试并加 `--update-goldens`，生成该环境图片。逐张审查内容、布局、文字及图标，比较差异，确认变化符合预期；不要仅为消除失败接受图片。
3. 更新该组 manifest 中的环境、SDK revision、执行方式及 SHA-256（测试文件、host、wallpaper、字体、依赖锁和全部图片）。新增环境也更新本表；仿真结果明确标注仿真。
4. 去掉 `--update-goldens` 再跑全部 8 例，确认真实渲染匹配，并保留验证日志供审查。

更新公共 fixture 或渲染后，需要在全部三个环境重新生成／审查／验证，共维护 24 张图片。升级 SDK 时同时复核三组环境记录；禁止用另一环境图片回退、跳过测试或放宽容差。
