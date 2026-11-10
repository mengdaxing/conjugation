# Android 构建验证 · 2026-11-09

交付文件：`dist/FrenchVerbs.apk`，57,563,098 字节（57.6 MB），已使用本地专用密钥签名。

- 版本：1.0.0（4），包名 `com.personal.frenchconjugation`。
- 最低 Android 9 / API 28；目标 API 36；仅 `arm64-v8a`。
- Skip 1.9.20，Skip Fuse `mode: native`，Swift 6.4.2 Android SDK，NDK r30，JDK 21。
- Swift 业务逻辑编译为原生共享库，SwiftUI 通过 SkipFuseUI / SkipUI 使用 Jetpack Compose；系统朗读使用小型安卓适配器。
- 交付 APK 与安装到模拟器并完成 UI 测试的 APK 逐字节相同。

SHA-256：`281203f354874e13e1985204d6ead1b482fd7623bacfafe06b37789a8b6fe2fd`

签名证书 SHA-256：`70b609597e8765b0494dd5500de0472a883f73221bb1234d458712836db7624f`

## 检查结果

`scripts/verify_apk.py` 通过：31 个 arm64 ELF 原生库（含应用模块和 Swift 运行库），所有 LOAD 段均满足 16 KB 页对齐；词库包含 776 个唯一动词、16 种时态、每种 6 个人称槽位；许可资源齐全；ZIP CRC 正常。

`apksigner verify` 和 `zipalign -c -P 16 4` 通过。安装包为不可调试的 Release，Manifest 不申请网络权限。

Debug 的原生 Swift 检查通过 40 项：写入阶段 16 项、强制结束进程后的读取阶段 24 项。覆盖词库、搜索、重音与 Unicode、主语、复合时态、命令式、人称筛选、收藏、排除动词、设置、成绩、错题、顺序轮次和重置行为。测试使用独立的 UserDefaults 存储。

Release 在 Android 11 / API 30 的 AOSP ATD arm64 模拟器上安装并通过完整流程：

1. 首页搜索 `perdre`，打开变位表，收藏动词。
2. 输入 `perds`，复粘到六个人称；确认软键盘仍显示。
3. 提交后 `je`、`tu` 正确，其余四行显示 `perd`、`perdons`、`perdez`、`perdent`。
4. 重试清空输入，再次作答并完成本轮。
5. 强制结束并重启，设置中累计正确仍为 2 次、收藏仍为 1 个动词；重试没有重复计分。

ATD 默认关闭绘制，测试脚本会启用绘制。模拟器使用 [Simple Keyboard 149](https://github.com/rkkr/simple-keyboard/releases/tag/149) 检查软键盘布局，该测试工具不包含在交付 APK 或源码压缩包中。

原 iOS 工程的 16 项单元测试及 5 项 UI 测试通过；最终共享输入布局调整后，额外重新运行“复粘”UI 测试并通过。

本次没有使用实体安卓手机测试。法语朗读需要设备系统安装可用的法语语音。

## 截图

- [首页](01-home.png)
- [变位表](02-reference.png)
- [软键盘与复粘](03a-keyboard-replicate.png)
- [六个人称输入](03-input-replicate.png)
- [判题与纠错](04-feedback.png)
- [练习完成](05-complete.png)
- [重启后的设置和成绩](06-settings-after-restart.png)

## 重建

环境准备及签名密钥备份见根目录 README。构建命令：

```bash
bash scripts/build_android.sh release
python3 scripts/verify_apk.py dist/FrenchVerbs.apk
python3 scripts/package_android_source.py
```

签名密钥及其密码配置留在本机，不包含在源码压缩包中。后续更新需使用相同的签名密钥。
