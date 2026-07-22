## Flutter v1.0.6

- 修复退出阅读器后有时无法再次进章（改由 Dart 监听可见页 URL，不依赖可能假死的表页定时器）
- 退出时中止隐藏 WebView 上的预取/切章收图，避免状态残留
- 进章立即显示收集进度
- 修复 iOS 关闭阅读器后表页跳回首页（可见 WebView 槽位稳定 + GlobalKey）

Android 请按 CPU 架构安装（真机优先 `arm64-v8a`）。iOS 用 Sideloadly 等对 unsigned IPA 重签侧载（免费账号约 7 天）。
