# 大肥鱼 DaFeiYuPet · 0.1.0 原生越狱预览

目标 iOS 15–17；**不是声明这些系统均已实机通过**。用户设备为 iPhone 14 Pro Max / iOS 17.0，自述多巴胺 3.0 隐根；不据此推断实际越狱分支，请先确认环境再选择包。Rootless 不是免越狱。工程由 axs-ios-tweaks 生成器创建，所有新增类/selector 使用 AxsDaFeiYuPet / axs_dafeiyupet 命名空间。

## 已实现

- 仅 SpringBoard 注入；PreferenceLoader 设置面板；默认禁用、默认不漫游。
- UIKit 非 key 悬浮窗口，只有角色中心触摸区接收单击/拖动；其余区域返回 nil 穿透，不创建 SpringBoard 输入框、不调用 makeKeyAndVisible。
- 单击挥手与文本气泡、拖动悬空动作、甩抛重力弹跳、闲置东张西望、可关闭的周期漫游、回初始位置。
- 大小 120/180/240/300pt、透明度 20–100%、仅主屏幕/主屏幕与前台 App 两种范围；锁屏始终隐藏（安全策略，不提供锁屏展示开关）。旋转/尺寸变化重新夹取边界。
- 四种动画 × 120 PNG 帧，220×124，约 12.5fps，来自上游已有透明 GIF 预览。**480 帧全部逐帧验证 alpha 含 0 和 255**；不是不透明视频黑底、不是 WebM 冒充 MOV。GIF 原有二值 alpha、分辨率较低，细节不及原 640×360 WebM。
- 单张当前帧 + 最多一个异步解码任务，串行后台队列；不批量 UIImageView.animationImages、无整段预解码。关闭/锁屏/范围外销毁窗口、清空图片并 invalidate displaylink；无 AVPlayer，自然无视频播放器残留。
- 原生 AI 聊天**在设置进程的 PreferenceBundle 页面**：主动输入 ≤2048 UTF-16 单位，OpenAI 兼容 HTTPS Base URL/模型，Keychain 保存/删除 Key。单请求、可取消、请求30秒/资源35秒、响应上限64KiB、回复显示最多4096单位、max_tokens=256、无历史、离页取消并清文本。拒绝重定向，不降级明文存 Key，不记录 Key/对话或网络详情。

## 边界与未做项

- AI 回复仅显示于原生设置页；**不会同步到桌宠气泡，也不能直接点击宠物弹出输入框**。桌宠气泡为本地预设文案。这是避免 SpringBoard keyWindow/键盘争夺的明确取舍；未增加独立 helper App/XPC 服务及其 entitlement 攻击面。
- 不嵌 Electron/Node/WebView；没有 OCR、读取任何 App 聊天、录音、TTS、音乐监听、碰撞音效、服装换色、106动作全库、多宠碰撞、双击映射、完整菜单、位置持久化或逐像素透明命中。
- 物理参考上游 shared/physics.ts 的 dt 上限/重力/恢复/摩擦/限速，在 UIKit 点坐标实现；拖动为直接跟手，松手用 UIPan velocity，不声称完整复制上游弹簧、轨迹峰值算法与挤压特效。
- 活动范围、前台覆盖、旋转、键盘和锁屏需要目标机手工验收。已知私有入口仅通过 NSClassFromString/respondsToSelector 和返回类型/参数数目检查后调用；无 SBLockScreenManager/isUILocked 时安全不显示。仅主屏幕模式无法判断前台时不强行创建浮层。
- 非 key UIKit window 在 iOS 15–17 各种 scene、系统弹窗/键盘、屏幕录制/AOD/横屏场景下的层级没有实机证明。窗口等级 UIAlert+1 不等同私有全局 scene 安全保证；首次体验建议先“仅主屏幕”，出现异常立即关闭插件。
- 开启时可见性定时器 2Hz、displaylink 30Hz、图片约12.5fps；不是零耗电。锁屏 Darwin 事件先销毁再复核，并用轮询兜底；无法承诺系统通知未送达时零帧闪现。未测 Instruments 峰值内存/能耗。

## 本地检查与构建

```sh
python3 -m pip install Pillow
cc -Wall -Wextra -Werror tests/Physics.c -lm -o /tmp/dafeiyupet-physics
/tmp/dafeiyupet-physics
python3 tests/check_source.py
# 以下必须是各自真实、独立的 Theos，且含 iPhoneOS16.5.sdk：
THEOS_ROOTLESS=/path/to/theos sh build.sh rootless
THEOS_ROOTHIDE=/path/to/roothide-theos sh build.sh roothide
python3 tests/check_package.py packages/实际文件名.deb rootless
python3 tests/check_package.py packages/实际文件名.deb roothide
```

SDK 固定16.5、最低15.0、arm64+arm64e；主插件与设置共用 AxsDaFeiYuPetBuild.mk。Rootless 用 theos/theos，RootHide 用 roothide/theos 的真实编译器/头文件/重定位库；不以仅修改 Architecture 冒充 RootHide。资源只从未转换逻辑路径转换一次，Rootless 使用 ROOT_PATH_NS_VAR；RootHide 使用 jbroot()。Rootless 配置在移动用户偏好目录，RootHide 同一逻辑路径经 jbroot 转换；面板是唯一配置写入方。

当前 iSH 缺 THEOS/Apple SDK，不能本地证明 Objective-C/Theos 构建。doctor 仅静态诊断且其 selector allowlist 对 UIKit override/NSURLSession delegate 有误报，不能作为编译成功依据。真实 CI 和产物验收见 IMPLEMENTATION.md。

## GitHub Actions

仅 workflow_dispatch；contents:read；只上传 Artifacts，不自动 push 构建、不创建 Release、不加源、不安装、不注销。两个 matrix job 各自克隆官方对应工具链和SDK，记录工具链/SDK commit、Xcode/clang版本，分别测试/编译/打包/检查 Mach-O arm64e 切片、嵌入签名与480透明帧。当前使用 macos-15-intel：首次实查 macos-14 runner 被平台拒绝后已修正。需要 GitHub Actions 可用额度、受支持macOS runner和访问GitHub/Theos SDK/PyPI/Homebrew的网络；供应链 HEAD 会变化，日志保留实际commit，后续宜固定验证过的commit。

## 手工验收矩阵（全部待真机，不以CI代替）

| 场景 | 操作与通过标准 |
|---|---|
| 环境确认 | 分别真实RootHide/Rootless设备；包架构对应；不要混装；记录设备/系统/越狱版本 |
| 默认状态 | 首次加载关闭，SpringBoard无浮层/无displaylink；设置入口正常 |
| 配置持久化 | 总开关、四档大小、五档透明度、范围、漫游保存；重开设置一致，通知及时生效 |
| 透明渲染 | 白/黑/彩色壁纸与App背景无黑矩形；动作切换透明，画质预览级 |
| 触摸穿透 | 宠物中心响应，四周和气泡下方App可点击/滑动；空白层不吞触摸；键盘输入不受影响 |
| 物理 | 慢拖放置、快速甩抛、四边反弹，长帧不飞出；回原位后速度清零 |
| 锁屏 | 锁屏/AOD/解锁反复20次；不可见且无残留displaylink；锁屏通知失效也应轮询隐藏 |
| 范围 | 仅主屏幕进App隐藏、返回恢复；覆盖模式测微信/QQ/视频/横屏/系统弹窗，不读App内容 |
| 旋转/安全区 | 横竖屏、控制中心、通知中心与多scene切换；边界不越屏，手势条和键盘无阻挡 |
| 关闭回收 | 播放中关闭20次，窗口/图片/displaylink释放，旧帧回调不得复活；检查SpringBoard内存/CPU |
| AI隔离 | URL/模型可改，Key存删不出plist/日志；Settings里输入/取消/退页，SpringBoard不被抢key |
| AI异常 | 401/超时/无网/302/巨大响应/错误JSON/快速重复发送，主线程可操作、旧请求取消、无Key泄漏 |
| 性能 | 30分钟待机/漫游/抛掷、反复开关100次，用Instruments/崩溃日志检查内存增长、耗电与卡顿 |

## 许可

原生实现与复用代码 MIT，保留根 LICENSE 和 LICENSES 上游原文；**动画/提示词/源视频与鲸鱼娘·大肥鱼二创形象禁止商用**，见 LICENSES/ARTWORK-NONCOMMERCIAL.md。MIT 不能覆盖素材限制；公开仓库开源预览不是付费分发授权。包内也安装许可证副本。
