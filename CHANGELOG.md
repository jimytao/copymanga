# CopyManga Flutter 变更记录

> 本文件只记录 **Flutter 版**（分支 `flutter` / Tag `flutter-v*`）。  
> Kotlin 原生版见 `../copymanga-src/CHANGELOG.md`（分支 `re_build` / Tag `v*`）。

---

## 2026-07-19 — v1.0.3：阅读器切章表 H5 同步 + 下一章收图加速

- **表页进度同步**：阅读器内切章时静默 `loadUrl` 可见 WebView 到目标章（抑制 `loadComic`），退出后详情/历史不再停在首开那一话。
- **下一章收图**：阅读器改为嵌在 `BrowserPage` Stack（不再 `Navigator.push` 全遮罩）；收图/预取时把隐藏 WebView 以 1×1 提到最顶，避免 rAF 被节流。
- **切章稳健性**：用户显式切章强制 `stopLoading` + 重载（不再挂接可能僵死的预取）；隐藏注入加 generation；停滞时清理预取状态。
- **收尾**：退出阅读器取消停滞计时/抑制标志/预取状态；置顶完成后再 `loadUrl`，避免在旧层级启动收图。
- 底栏增加关闭按钮（系统返回同样退出阅读器）。
- **版本**：`1.0.3+4`。

## 2026-07-19 — v1.0.2：暗色启动白闪 + 发版 SOP 加固

- **暗色白闪**：`AT_DOCUMENT_START` UserScript + WebView `underPageBackgroundColor` 黑底 + `onLoadStart` 即刻注入；暗色 Splash 黑底过渡（不再等 `progress>2`）。
- **workflow**：标明 `copymanga_flutter` ↔ `_flutter_wt` 单向同步；关键文件禁止删除/截断为空；发版前完整性检查。
- **版本**：`1.0.2+3`。

## 2026-07-19 — v1.0.1：iOS 全面屏 / 键盘抖动 / 图标启动图

- **全面屏**：iOS 改用 `edgeToEdge`；上界贴刘海下沿；下界读系统 Home 指示条高度（`safeAreaInsets` / `viewPadding.bottom`，会话缓存；读不到时刘海机回退 34pt）。
- **网页外底色**：跟 App 暗色开关（浅白/深黑），`themeMode` 不再跟系统；修好「网页白、壳黑」反差。
- **键盘 / 抖动**：`resizeToAvoidBottomInset: false` + 剥离 `viewInsets`；顶栏 inset 用 `viewPadding`；WKWebView `contentInsetAdjustmentBehavior=NEVER`、关侧滑返回与输入附件条。
- **阅读器回归**：退出不再写回 `manual`；统一 `AppSystemUi`；iOS 藏状态栏用 `immersiveSticky`。
- **图标 / 启动**：补齐 AppIcon + 橙色 LaunchScreen；显示名「拷贝漫画」；Main.storyboard 同色防闪白。
- **版本**：`1.0.1+2`。

## 2026-07-19 — v1.0.0：跨平台首发（正式签名 + GitHub Release）

- **版本**：`1.0.0+1`（Android versionName=1.0.0 / versionCode=1）。
- **签名**：与 Kotlin 版共用工作区根 `keystore.jks`；`flutter build apk --release` 自动签名。
- **发布渠道**：分支 `flutter`；Tag / Release **`flutter-v1.0.0`**（与 Kotlin 的 `v*` 分离）。
- **产物**：按 ABI split 的三份 APK（`armeabi-v7a` / `arm64-v8a` / `x86_64`，约 19–23MB）+ `CopyManga-flutter-1.0.0-unsigned.ipa`；发版禁止上传未 split 胖包。
- **启动**：有缓存源秒开；首次测速显示橙色 Splash；WebView 进程预热。
- **图标 / FAB**：原版同款启动图标；「我的下载」悬浮钮默认可拖至右侧偏上并记住位置。
- **阅读器**：三模式、断点续读（看完清零）、原地切章、80% 预取、翻到头切章、页码跳转、信息栏；窄屏底栏不再溢出。
- **下载**：批量多选下载、分层存储、离线上下章、`.done` 完成标记；设置页亦可进入「我的下载」。
- **源站**：内容校验测速、手动/自动模式、缓存清理、无网引导离线。
- **鲁棒性**：切章 PageController 单例、进度落盘防串章、收图 uuid 校验、旧章 `setLoadingDialog(false)` 不再拆新章加载框等（详见开发期自查）。

### 开发期里程碑（首发前合并叙述）

- 双 WebView 从 Headless 改为内联真实控件，修复 rAF 被节流导致的收图极慢。
- 收图停滞检测替代硬超时；章节切换对齐原生预取/原地换数据逻辑。
- 功能对齐原生：暗色模式、音量键翻页（Android）、JS 弹窗自动确认、双击状态栏、批量下载流水线等。
- 源站列表移除过期 `2025copy.com`，新增 `www.copymanga.site`；测速改为正文特征校验。
