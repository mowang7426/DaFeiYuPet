# 大肥鱼 0.1.0 原生预览实现报告

日期：2026-11-14。工程：`/var/minis/workspace/dafeiyu-ios`。目标：iOS 15–17 越狱设备；用户设备按其自述记录为 iPhone 14 Pro Max / iOS 17.0 / 多巴胺3.0隐根，未擅自改写此信息，也未将其当作已验证越狱环境。

## 1. 权限与实际操作

- 先读取 axs-ios-tweaks/SKILL.md 及 conventions/preferences/jailbreak-adaptation/building 四份 reference，再通过生成器创建 DaFeiYuPet / dafeiyupet / 大肥鱼，带 PreferenceLoader、默认 SpringBoard 单进程注入。
- 原先只本地工作的限制，在收到用户“公开仓库编译”的明确补充授权后才执行远端操作。先用 API 查当前账号及同名仓库，账号为 `mowang7426`，`DaFeiYuPet` 不存在，因此创建新的公开仓库：<https://github.com/mowang7426/DaFeiYuPet>。
- API auto_init 仅生成 bootstrap `main` README；实际实现始终推送 `feature/preview-0.1.0`，随后将新仓默认分支设为该预览分支，以便注册 workflow_dispatch；未直接改写 main、未 force push、未改任何旧仓库。
- 只手动触发 Actions，权限 contents:read，上传 Artifacts；未创建 Release、未加源、未安装、未重启/注销设备。Git 认证用临时 askpass 从环境变量读取令牌，remote URL 和源码中无令牌。
- 参考源码目录与审查报告只读。只读检查过 shared 中 IslandDigest 的源码归档工作流与 SplitView 构建档案；没有运行参考仓库脚本，没有修改旧项目。

## 2. 原生实现与边界

### 桌宠核心

- 主插件为 Objective-C/Logos + UIKit/QuartzCore；无 Electron、Node、WebView。仅 Hook SpringBoard 的 applicationDidFinishLaunching:，调用专属控制器。
- 以实际 UIApplication connectedScenes 中可用的前台 UIWindowScene 创建窗口，无可用 scene 时退回 initWithFrame。没有伪造私有类声明。私有入口只经 NSClassFromString、respondsToSelector、参数数目、返回类型校验后 objc_msgSend：SBLockScreenManager.sharedInstance/isUILocked、SpringBoard 的 _accessibilityFrontMostApplication、返回对象的 bundleIdentifier。
- 默认总开关关闭、默认不漫游、默认仅主屏幕。总开关、大小、透明度、范围、漫游、回原位都在设置面板；面板唯一写配置，原子存盘后镜像快照和发专属 Darwin 通知。消费者只读不可变快照和类型/区间夹取。
- 桌面角色中心区域接收单击和拖动，透明边缘及气泡区域返回 nil 穿透。**覆盖第三方前台 App 时角色本身也完全穿透**：预览版不允许在 App 内直接拖/点宠物，以避免宠物叠在键盘上截获输入。前台状态未知时不接受触摸；本地 UIKit 键盘通知出现时销毁浮层。任何窗口都不调用 makeKeyAndVisible，canBecomeKeyWindow 返回 NO。
- 单击播放挥手和本地文本气泡；拖动播放悬空动作；松手速度大于阈值进入甩抛；重力1400pt/s²、恢复系数0.78、地面摩擦2.5/s、速度软上限3600、dt上限0.05秒；闲置每12秒东张西望；可选周期轻跳漫游。回原位清速度，不持久化拖动位置。
- 锁屏始终隐藏，不提供危险的锁屏显示选项；真实 Darwin lockstate 事件先销毁再复核，以2Hz轮询兜底。范围外销毁窗口；旋转/scene尺寸变化按真实坐标空间重新放回边界内。
- 停用时取消可见性定时器、invalidate displaylink、释放窗口/图片/气泡；通过 generation 丢弃过期解码回调，不会复活浮层。配置/锁屏/键盘通知观察者仅为进程生命周期轻量观察者。没有 AVPlayer，因采用帧序列，所以不存在视频播放器残留。

### 真透明素材与有界内存

- 不把106个VP9-alpha WebM直接交给iOS播放器、不把黑底视频伪装成透明视频。
- 已只读检查上游 Mac encode_hevc_alpha.sh / Swift AVAssetWriter hevcWithAlpha 方案，但没有执行参考仓库脚本。当前 iSH FFmpeg 的可用 VP9 解码未提供 libvpx-alpha 保障，因此不做不可信的WebM黑底降级。
- 使用上游已经具备透明索引的四个GIF预览，独立 Pillow 脚本按 GIF disposal 正确合成后导出 RGBA PNG。idle/look/tap/drag各120帧，共480帧、220×124、每帧约0.08秒；逐帧验证alpha极值为0与255。GIF来源/散列/帧数在 Assets/provenance.json。视觉叠蓝底检查也确认背景透明。
- 这是二值alpha、预览分辨率，非原640×360视频质量；总PNG安装资源约7.5MiB。只保持当前显示帧与最多一个串行后台解码任务，未使用 animationImages、imageNamed 全局缓存或整段预解码；单220×124 RGBA面约106.6KiB，实际UIKit/解码器总RSS仍需真机测量，不能以这个单面估算冒充实测峰值。

### 原生 AI 的隔离取舍

- 聊天与 Keychain 全部在 PreferenceBundle 页面，即**设置进程**；SpringBoard 插件不链接 Security，不含网络请求、文本输入控件或对话存储。
- 支持 OpenAI 兼容 HTTPS Base URL/模型，默认 api.openai.com/v1 与 gpt-4o-mini；URL要求无user/password/query/fragment，Base URL≤2048、模型1–128，拒绝HTTP和所有重定向，防Authorization跨域转发。
- Key只保存到插件专属 Keychain service/account，WhenUnlockedThisDeviceOnly；支持删除，存储失败不回退明文。不读取已有Key显示在界面。网络错误仅泛化状态，不记录Key、请求、回复或服务端错误正文。
- 主动输入≤2048 UTF-16单位、max_tokens=256、非流式、单活动请求；新请求取消旧请求，可手动取消，离页取消/清输入和回复；请求30秒、资源35秒；累计响应超过64KiB取消；格式校验后最多显示4096单位。使用 ephemeral NSURLSession，无历史/cookie/cache，网络不在SpringBoard执行。
- 聊天页面使用 UIScrollView + keyboardLayoutGuide，减少小屏键盘挡发送按钮的问题。
- 明确未实现：独立helper App/XPC服务、从宠物直接呼出聊天、AI回复跨进程同步到宠物气泡。当前气泡只是本地预设台词；这样避免为首次预览引入 SpringBoard keyWindow 抢占、额外IPC和helper entitlement风险。Keychain权限和真实服务连通性均尚未真机验证。

## 3. 环境与双包真实构建

- 本地存在 Python3、Pillow、cc/clang、make、dpkg-deb；THEOS未设置，也没有已配置Apple SDK。已运行独立编写的纯C/静态/媒体测试；没有将doctor当编译器。
- doctor 对系统 override/协议实现 viewDidLoad、viewDidDisappear、textView、URLSession、hitTest、canBecomeKeyWindow 产生命名误报，另正确指出THEOS未设置；记录为诊断失败而不是伪称通过。这些系统selector按规范必须保留原名。
- Rootless job独立克隆 https://github.com/theos/theos.git；RootHide job独立克隆 https://github.com/roothide/theos.git 和其 roothide/headers、库、scheme；不是同一二进制改Architecture。路径宏在真实roothide scheme下明确编译jbroot分支。
- 主插件和面板统一 arm64+arm64e、最低iOS15.0。上游SDK目录名固定 iPhoneOS16.5.sdk，**实查SDKSettings实际Version为16.4，最终Mach-O LC_BUILD_VERSION SDK也为16.4.0**；此处不能声称使用真实16.5 SDK。目录名只是查找名，构建日志保留元数据。
- 采用macos-15-intel runner，实查Xcode16.4/Apple clang17。旧参考macos-14在本次真实CI被GitHub拒绝，注释为不支持macos-14-arm64-us-default，已修复而非隐瞒。
- Theos/ldid签名为CMS缺省、flags=0的常见越狱格式，macOS codesign --verify 将其报为not signed at all，首轮严格验证因此失败。随后实现独立CodeDirectory验签：每个MachO切片的每个SHA-1/SHA-256代码页、特殊槽逐个哈希比对，并用修改代码页负例确认必拒绝。此为签名完整性验证，**不是Apple开发者证书信任链或真机CoreTrust加载认证**。

### 可复现命令

```sh
cd /var/minis/workspace/dafeiyu-ios
cc -Wall -Wextra -Werror tests/Physics.c -lm -o /tmp/dafeiyupet-physics
/tmp/dafeiyupet-physics
python3 tests/check_source.py
THEOS_ROOTLESS=/path/to/theos sh build.sh rootless
THEOS_ROOTHIDE=/path/to/roothide-theos sh build.sh roothide
python3 tests/check_package.py packages/com.axs.dafeiyupet_0.1.0_iphoneos-arm64.deb rootless
python3 tests/check_package.py packages/com.axs.dafeiyupet_0.1.0_iphoneos-arm64e.deb roothide
```

GitHub：在预览默认分支的 Actions → DaFeiYuPet preview build → Run workflow 手动触发；无push/PR自动触发、无Release。需要可用GitHub Actions额度、macOS15 Intel runner，以及GitHub、Theos SDK、Homebrew、PyPI网络。日志记录实际工具链/SDK commit；当前取HEAD而非锁定供应链，后续建议固定已验证commit。

## 4. 修改文件清单

新工程共524个跟踪文件（含本文；480个动画PNG和1个设置图标）。未改参考目录与旧项目。按功能列出完整非动画路径，480帧以无遗漏编号范围列出：

```text
.github/workflows/build.yml
.gitignore
Assets/provenance.json
AxsDaFeiYuPet.plist
AxsDaFeiYuPetBuild.mk
Makefile
build.sh
control
tweak.json
README.md
IMPLEMENTATION.md
Headers/AxsDaFeiYuPetPrivate.h
Hooks/AxsDaFeiYuPetMain.xm
Sources/AxsDaFeiYuPetConfig.h
Sources/AxsDaFeiYuPetConfig.m
Sources/AxsDaFeiYuPetController.h
Sources/AxsDaFeiYuPetController.m
Sources/AxsDaFeiYuPetPaths.h
Sources/AxsDaFeiYuPetPhysics.h
Sources/AxsDaFeiYuPetPreferences.h
AxsDaFeiYuPetPrefs/Makefile
AxsDaFeiYuPetPrefs/AxsDaFeiYuPetRootListController.h
AxsDaFeiYuPetPrefs/AxsDaFeiYuPetRootListController.m
AxsDaFeiYuPetPrefs/AxsDaFeiYuPetChatController.h
AxsDaFeiYuPetPrefs/AxsDaFeiYuPetChatController.m
AxsDaFeiYuPetPrefs/Resources/AxsDaFeiYuPetRoot.plist
AxsDaFeiYuPetPrefs/Resources/Info.plist
AxsDaFeiYuPetPrefs/Resources/icon@2x.png
LICENSE
LICENSES/ARTWORK-NONCOMMERCIAL.md
LICENSES/upstream-package-MIT.txt
LICENSES/upstream-ref-MIT.txt
layout/Library/PreferenceLoader/Preferences/AxsDaFeiYuPetPrefs.plist
layout/Library/Application Support/AxsDaFeiYuPet/manifest.plist
layout/Library/Application Support/AxsDaFeiYuPet/idle/0000.png … 0119.png
layout/Library/Application Support/AxsDaFeiYuPet/look/0000.png … 0119.png
layout/Library/Application Support/AxsDaFeiYuPet/tap/0000.png … 0119.png
layout/Library/Application Support/AxsDaFeiYuPet/drag/0000.png … 0119.png
layout/usr/share/doc/com.axs.dafeiyupet/LICENSE
layout/usr/share/doc/com.axs.dafeiyupet/ARTWORK-NONCOMMERCIAL.md
layout/usr/share/doc/com.axs.dafeiyupet/upstream-package-MIT.txt
layout/usr/share/doc/com.axs.dafeiyupet/upstream-ref-MIT.txt
scripts/configure.py
scripts/convert_frames.py
tests/Physics.c
tests/check_source.py
tests/check_package.py
tests/signature_integrity.py
```

源代码MIT及上游版权原文均保留；素材/源视频/提示词与大肥鱼社区二创形象仅限非商业，许可证也打进deb。未引入授权不清晰字体/额外音效。公开源码和Artifacts不等于商业授权。

## 5. 本地验证、未做项与剩余风险

已执行的本地验证：

1. 纯C物理/数值配置夹取测试：非有限值、速度软上限、2万步边界/最终静止、长dt夹取、零面积边界，全部通过。
2. 默认配置与源契约：SpringBoard唯一过滤器、默认禁用/不漫游/仅主屏幕、大小透明度默认值、bundle版本0.1.0、最低15.0、单图异步/过期generation、关闭invalidate、键盘/前台App安全门控、AI Keychain/请求限制、无NSLog/os_log、仅手动双工具链Artifacts工作流，全部通过。
3. 480帧逐帧RGBA/尺寸/alpha范围检查通过；不以容器alpha标签代替像素验证。
4. 已取回中间成功编译的两环境真实deb，对每个主dylib与设置可执行文件两切片逐页签名哈希验签、篡改负例、部署15.0/实际SDK16.4、RootHide libroothide加载路径、Rootless /var/jb布局、面板入口/480帧/许可证进行独立本地检查，通过。最终版本另见下节真实CI与复核记录。
5. doctor不是编译，输出误报及缺THEOS按事实记录。真实Objective-C/Theos编译以GitHub运行记录为证。

**尚未做、不得推断已通过：** 用户真机安装/加载、PreferenceLoader写入权限与Darwin通知实测、RootHide随机根下资源与配置访问、SpringBoard前台App覆盖/scene行为、锁屏/AOD零闪现保证、旋转、Spotlight/第三方键盘交互、实际OpenAI兼容服务请求与Keychain、Instruments峰值内存/CPU/耗电、连续运行稳定性。iOS15/16/17均是目标范围，不是全版本实机认证。

已知功能收缩：只保留4动作的220×124透明预览帧；没有全106动作、视频级画质、上游完整弹簧/轨迹峰值物理、挤压特效、碰撞声、音乐监听、换装、双击映射、完整菜单、持久位置、多宠、语音、OCR或聊天读取。前台App只能看宠物而不接收宠物交互，输入/AI仅在设置内，AI回复尚未跨进程显示在气泡。

### 推荐后续顺序

1. 在确认真实越狱分支后，先由用户手动安装正确包，默认保持关闭；优先仅主屏幕小尺寸体验。对照README的完整手工矩阵逐项记录，而非直接开启App覆盖。出现异常立即关闭；本次没有代用户执行安装/注销。
2. 先验证设置持久化、RootHide路径、锁屏/键盘/scene与资源回收，再用Instruments检查30分钟/100次开关与耗电；覆盖层级问题优先收窄功能，不应为“看起来能盖App”改用全App注入或抢keyWindow。
3. 再将高质量核心WebM子集在受信任Mac上通过独立审核的AVFoundation hevcWithAlpha链转换，做实际解码alpha验证；保留本帧序列作为可靠fallback，单播放器/有界缓存，不能使用黑底视频蒙混。
4. 若确需从宠物输入/回复气泡，另设计最小权限独立helper与经鉴权、有大小上限的IPC，不把输入/网络搬回SpringBoard，也不通过偏好文件存对话或密钥。
5. 锁定本次通过的Theos/SDK/Actions依赖commit，增加真机自动化与实际配置文件损坏/权限失败测试；商用前另取得素材/二创形象授权或替换原创资产。

## 6. 最终真实CI结果与本地Artifacts复核

最终源码构建提交：`b3c4bd6505afd566065a1b1105a832fe77588a43`（预览分支）。
最终运行：<https://github.com/mowang7426/DaFeiYuPet/actions/runs/43542101650>，workflow_dispatch，**整体success**，两个job均从依赖安装、独立工具链、宿主测试、Objective-C/Logos编译、打包到实际包验收全部success：

| 环境 | Job ID | Artifact ID | deb |
| --- | --- | --- | --- |
| Rootless | 132284762607 | 14092388157 | com.axs.dafeiyupet_0.1.0_iphoneos-arm64.deb |
| RootHide | 132284762858 | 14092570869 | com.axs.dafeiyupet_0.1.0_iphoneos-arm64e.deb |

真实工具链记录：

- Rootless Theos `8167f59de02fd32cf45b16bfcb1330dfa5c9974c`，headers `25ef5c99a31d600cf3a7b88922c1f7a4029c1417`，vendor/lib `6f2af307568e6b8c52181d26314b0cd69ffaf188`。
- RootHide Theos `958fea4f779943505b15b93c88bb4db8d97b346d`，headers `e1132e2bbc3ca15c50e2311bcd349cb7353409e1`，vendor/lib `85e9b5b8aff11bbefc59525c64c8f55149926e56`。
- SDK仓库commit `0222fd5413cf4b9af096f37b4621afa2688572f7`，目录名16.5但Version/CanonicalName实际16.4；二进制SDK16.4.0，最低部署15.0。Runner Xcode16.4，Apple clang17.0.0。
- 保留的编译警告包括链接器 `-multiply_defined is obsolete`；没有用全局屏蔽警告来伪造通过。

最终文件已下载到 `/var/minis/shared/dafeiyupet-preview/`，并再次使用本地独立检查器审核下载后的deb，而不只相信Actions绿色状态。GitHub API公布的两个Artifact ZIP摘要与下载字节完全一致，包内SHA256SUMS与本地deb摘要一致。

| 环境 | deb字节数 | SHA-256 |
| --- | ---: | --- |
| Rootless | 6611502 | `fcb5aa9a102ead4b5b7ef59592edef3b948fd8b997cb76b31d8c2b3159239a2a` |
| RootHide | 6610194 | `d52566772482de511e2cda03a642e58c35b57f0f32e3d11f004615020e3c5003` |

本地二次审核通过内容：包名/0.1.0/依赖/两个不同Architecture；主dylib与设置bundle可执行文件均真实具有arm64+arm64e切片；所有切片LC_BUILD_VERSION最低15.0；所有SHA-1/SHA-256 CodeDirectory代码页与特殊槽完整性正确，篡改负例被拒绝；SpringBoard唯一注入过滤器；PreferenceLoader入口；480个真alpha PNG；manifest；包内MIT和素材非商业许可；Rootless实际/var/jb安装布局与rpath；RootHide实际Library布局以及`@loader_path/.jbroot/usr/lib/libroothide.dylib`链接，证明不是改包架构冒充。

共享交付目录包含：两个顶层deb、两个原始Artifact ZIP、分别解压的rootless/roothide包与build日志、`rootless-independent-check.txt` / `roothide-independent-check.txt`、`run.json` / `jobs.json` / `verification.json`，以及 `logs/` 下两个完整job文本与完整run日志ZIP。另保留最终源码归档与总SHA256SUMS供离线复核。

中间运行记录也可追溯：43540092628为旧runner配置被平台取消；43540259843两环境真实编译成功但不适配ldid的macOS证书验证失败；43541006928、43541605793、43541960162为逐步加入锁屏/scene/键盘门控后的双环境成功运行。最终交付只选43542101650版本一致性修复后的包，不混用旧包。

**结论：已交付真实可编译、双环境打包及严格产物复核通过的原生0.1.0预览，不是空壳；没有真机加载和运行验收，不能称“已支持全部iOS15–17设备”或“已在用户17.0设备验证”。当前构建没有剩余阻塞；余下阻塞是真机权限、窗口/键盘/锁屏行为、实际AI服务/Keychain及性能稳定性验收。**
