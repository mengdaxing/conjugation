# 验证记录

构建日期：2026-11-08（Europe/Paris）。

- Xcode 26.2（17C52），iPhoneOS / iPhoneSimulator SDK 26.2。
- 模拟器：iPhone 17 Pro，iOS 26.3.1。
- 9 项 XCTest 单元测试全部通过。
- 3 项 XCUITest 界面测试全部通过：六人称输入、逐项检查 / 纠错 / 重试、搜索并完成单动词练习、时态和人称选择、收藏。
- 键盘补充检查：带预测栏与重音工具栏时，提交按钮可见且可以点击；输入和纠错流程复测通过。
- Release archive 成功。
- IPA 自动检查通过：Payload 结构完整、arm64 Mach-O、iOS 真机平台、最低 iOS 16.0、776 个唯一动词、16 种时态、Assets 与许可齐全、ZIP CRC 正常。
- codesign 检查为未签名；没有描述文件、代码签名或开发者 entitlement。
- build 2：CFBundleDisplayName / CFBundleName 均为纯 ASCII 字母 FrenchVerbs，保留原 Bundle ID；IPA 校验器增加 SideStore 注册名称检查，构建脚本同时导出 Conjugation-SideStore.ipa。
- build 3：替换旧的全黑图标；新图标经过目视检查以及源文件 / iPhone / iPad 编译资源的像素亮度、颜色和对比度验证。构建号增加到 3，额外提供 Conjugation-Icon.ipa。
- 真机重签和安装由使用者完成，本次没有使用个人证书或执行真机安装。

完整测试结果保存在本地 build/FinalTests.xcresult，键盘布局补充检查在 build/KeyboardFinal.xcresult；测试截图见本目录 screenshots/。构建和测试中间产物不包含在源码压缩包中。

## 2026-11-09 · build 4 复粘按钮

- 当前有焦点的输入框右侧显示浅蓝色“复粘”胶囊按钮；没有焦点或提交后隐藏。
- 当前内容原样覆盖本题其他已选人称，保持源输入框焦点及键盘；空内容可以清空其他框。
- 2 项针对性界面测试通过：新增复粘流程，以及原有六人称输入 / 检查 / 纠错 / 重试流程，0 失败。
- 复粘测试验证第一行、中间行和最后一行焦点，按钮相对位置与唯一性，覆盖已有内容，保持输入焦点，空内容复制及隐藏条件。
- 测试结果：build/ReplicateTests.xcresult；截图：docs/screenshots/12-replicate-focused-input.png 与 docs/screenshots/13-replicate-filled-answers.png。
- Release archive 和未签名 IPA 检查通过，构建号为 4；英文签名名称、新图标及原 Bundle ID 保留。

## 2026-11-09 · build 5 错误日志

- 首页底部右侧新增浅蓝色“错误日志”入口；日志按时间显示 Warning / Error，支持搜索、级别筛选、详情复制、导出 TXT 和清空。
- 应用日志直接落盘，最多保留最近 1000 条。覆盖词库 / 学习记录读取异常、无效配置、缺少法语语音、内存警告以及日志自身的存储 / 导出异常。
- 前台每 15 秒、进入日志页或手动刷新时读取当前应用进程可用的统一日志。error / fault 记为 Error，notice 仅在以明确 Warning / WARN 标记开头时记为 Warning，普通 info / debug / notice 排除。
- iOS 仅允许读取本进程的系统日志；不读取整个设备日志，不保证捕获被系统终止前的崩溃。采集失败会记录一条警告，应用自身日志仍可继续保存。答题错误不进入程序日志。
- 16 项单元测试全部通过，其中新增 7 项验证条数限制与去重、并发写入、重启恢复、中文与重音字符、TXT 导出、清空持久化、损坏历史保留与恢复、写盘失败降级、系统级别判定及真实学习记录解码异常接入。
- 错误日志完整 UI 测试通过：入口、两种级别筛选、详情、系统分享面板导出、重启保留、清空与再次重启后移除。另复测原有复粘 UI 流程通过。
- 最终结果：build/DiagnosticVerified.xcresult；复粘回归结果：build/DiagnosticTests.xcresult 中的 testReplicateFocusedAnswerAcrossPeople。截图：docs/screenshots/14-error-logs-entry.png 至 18-empty-error-logs.png。截图中的 UI_DIAGNOSTIC 为 Debug 测试数据，Release IPA 已检查不含这些测试标记。
- Release archive 成功；Conjugation-Logs.ipa 为 build 5、iOS 16+、真机 arm64、未签名。IPA 结构 / CRC、ASCII 签名名称、776 动词 / 16 时态及源图标 / iPhone / iPad 编译图标验证通过。
- 共享源码整理到 Sources/Conjugation 后，iOS 工程生成器同步使用该目录，独立 IPA 继续无需 Skip 依赖。归档期间 iOS Swift 源码散列一致。

## 2026-11-09 · iOS build 7 语音播放修复

- 根据 build 5 导出的 Core Audio 连接失败（-66748 / XPC 4099）和 AVAudioBuffer 空缓冲区日志排查；原代码每次朗读前无条件停止，没有显式配置 / 激活音频会话，也没有中断恢复和失败反馈。
- iOS 使用 `.playback` / `.spokenAudio` 会话，播放前激活，完成或取消后释放并通知其他音频应用恢复。练习页与变位表共用一个持久合成器，通过页面所有权避免退出旧页面时停止新页面的朗读。
- 连续请求先等待取消回调，仅保留最新内容；未发出取消回调时在 1 秒后重建引擎。8 秒未收到开始回调时重建并重试一次，再次失败则显示提示并记入“法语朗读”日志。不向非语音错误日志隐藏或过滤任何系统报错。
- 缺少法语语音时显示下载提示，取消原来的默认语言回退。电话中断、进入后台和媒体服务重启时清除当前请求；媒体服务重启后等待用户再次点击，重新创建音频对象和配置会话。
- `build/SpeechFinalTests.xcresult`：29 项单元测试、2 项界面测试，全部通过。13 项语音测试覆盖会话激活顺序、完成后重播、快速替换、旧回调隔离、页面所有权、取消未启动请求、音频激活失败、语音资源失败、取消回调缺失、启动超时的单次重试、媒体重启、电话中断与后台停止。系统引擎集成测试实际朗读 `bonjour` 和 `salut`，逐次收到开始 / 结束回调；未跳过。
- 界面测试覆盖变位表多次切换 / 重复点击朗读、进入练习后朗读答案、下一题停止及返回变位表重播；另复测原有六人称输入 / 检查 / 纠错 / 重试流程。截图：`docs/screenshots/19-speech-reference-replay.png`。
- 测试环境：Xcode 26.2，iPhone 17 Pro / iOS 26.3 模拟器。模拟器中成功开始 / 完成的朗读仍伴随 `AVAudioBuffer.mm:281` 日志，因此不能仅凭这条日志判断用户是否听到声音。未在用户的 iOS 26.7.2 真机上验证实际音频输出、静音开关、蓝牙或通话后的音频路由。
- Apple 参考：[AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)、[取消回调的适用范围](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate/speechsynthesizer(_:didcancel:))、[媒体服务重启后的恢复](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification)。
- Release archive 成功；`dist/MyConju-SpeechFix.ipa` 与 `dist/MyConju-unsigned.ipa` 为相同的 build 7 真机包。已验证 iOS 16+、arm64、未签名、原包标识、ASCII 签名名称、图标、词库 / 许可、ZIP CRC，且未包含 Debug 日志测试数据。SHA-256 见 `dist/MyConju-iOS-SHA256SUMS.txt`。原位重签升级可沿用学习记录，未执行真机签名 / 安装。

## 2026-11-10 · v1.0.0 开源发布核验

- 发布已有的 1.0.0 / build 7 安装包：`MyConju-unsigned.ipa` 和 `MyConju.apk`；此次仅整理发布文档与 Git 忽略规则，没有更改应用源码或重新构建二进制。
- iOS 的 15 个 Swift 源文件与打包时保存的源码归档一致；Android 最新源码归档中的 175 个文件在发布文档整理前与工作目录逐字节一致。
- 重新运行 `scripts/verify_ipa.py` 和 `scripts/verify_apk.py`，两个安装包的版本、平台、架构、词库、许可和 ZIP CRC 检查全部通过；Android 的 31 个 arm64 原生库满足 16 KB 页对齐。
- Android `apksigner verify --verbose --print-certs` 通过，使用 APK Signature Scheme v2；证书 SHA-256 为 `70b609597e8765b0494dd5500de0472a883f73221bb1234d458712836db7624f`，与既有发布证书一致。
- IPA SHA-256：`b9d4a79357f0223f00fa8b0ec9063d360fac4fa6de5f9f6aa023c05474ac57df`。
- APK SHA-256：`27d0116d1aa66047677f9ac7cd82d1def34e5d6fa5be1c330808b9e28e295fd7`。
- 公开源码排除签名密钥、密码配置、安装包和构建缓存；完整源码归档从发布标签生成，Release 提供 `SHA256SUMS.txt`。
- 此次发布核验未重新运行模拟器 UI 或真机测试；先前功能测试的范围和限制见上文及 `docs/android/VALIDATION.md`。
