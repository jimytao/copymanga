## Flutter v1.0.15 — 修复条漫末尾二次滑动无法切章

### 问题
部分 Android 系统的条漫阅读器在章节底部会先提示「再次滑动加载下一章」，
但第二次滑动没有切换章节。

### 修复
- 条漫在部分 Android 缺少 `OverscrollNotification` 时使用的 ScrollUpdate 兜底，
  现与 Overscroll 统一进入同一个章节边界状态机。
- 修复两类系统通知前后交替时，第一次提示与第二次确认被不同状态机分别计数的问题。
- 增加对应的状态机回归用例。

### 资产
- Android：`CopyManga-flutter-1.0.15-{abi}.apk`（split-per-abi）
- iOS：`CopyManga-flutter-1.0.15-unsigned.ipa`（Actions 自动构建，需 Sideloadly 等重签侧载）

### 版本
`1.0.15+16`
