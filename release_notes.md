## Flutter v1.0.13 — 修复日漫横向章节边界换章

### 问题
iOS / 日漫（右开）横向阅读时：
- 章节**最后一页向右滑**应进入下一章确认，此前完全无效
- **向左滑**反而出现「再次滑动加载下一章」
- 出现提示后第二次滑动仍无法换章

### 修复
- 统一方向映射：日漫右滑=下一页/下一章，左开左滑=下一页/下一章
- 章节边界第一划 / 第二划 / overscroll / 诊断共用同一映射，避免 armed 状态与真实方向不一致
- 未改动 Android 翻页手感（Physics / 缩放 / 手势协调器）

### 资产
- Android：`CopyManga-flutter-1.0.13-{abi}.apk`（split-per-abi）
- iOS：`CopyManga-flutter-1.0.13-unsigned.ipa`（Actions 自动构建，需 Sideloadly 等重签侧载）

### 版本
`1.0.13+14`
