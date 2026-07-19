## 2026-07-19 — v1.0.0：首个正式签名版

- **版本号**：`1.0.0+1`（Android versionName=1.0.0 / versionCode=1）。
- **正式签名**：`android/app/signing.properties` + 工作区根 `keystore.jks`（与 Kotlin 版共用）；`flutter build apk --release` 自动签名。
- **Git**：独立分支 `flutter`；Release Tag 使用 `flutter-v1.0.0`（与 Kotlin 的 `v*` 分离），推送后 Actions 编 unsigned IPA。
- **发版 SOP**：见本目录 `workflow.md`（与 `copymanga-src/workflow.md` 分立）。
- **启动加速与开机过渡**：缓存源秒开、首次测速显示橙色 Splash。
