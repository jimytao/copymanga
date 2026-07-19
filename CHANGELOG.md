# CopyManga Flutter 变更记录

> 本文件只记录 **Flutter 版**（分支 `flutter` / Tag `flutter-v*`）。  
> Kotlin 原生版见 `../copymanga-src/CHANGELOG.md`（分支 `re_build` / Tag `v*`）。

---

## 2026-07-19 — v1.0.0：跨平台首发（正式签名 + GitHub Release）

- **版本**：`1.0.0+1`（Android versionName=1.0.0 / versionCode=1）。
- **签名**：与 Kotlin 版共用工作区根 `keystore.jks`；`flutter build apk --release` 自动签名。
- **发布渠道**：分支 `flutter`；Tag / Release **`flutter-v1.0.0`**（与 Kotlin 的 `v*` 分离）。
- **产物**：`CopyManga-flutter-1.0.0.apk` + Actions 产出的 `CopyManga-flutter-1.0.0-unsigned.ipa`（Sideloadly 重签侧载）。
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
