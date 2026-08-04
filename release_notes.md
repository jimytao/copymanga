## Flutter v1.0.12

正式修复阅读器手势仲裁与章节边界双滑。

### 变更

- **横滑**：未缩放时不再挂载 InteractiveViewer，由 `ReaderGestureCoordinator` 仲裁单指翻页 / 双指缩放 / 放大平移，缓解 Android 快滑翻页不灵敏。
- **章节双滑**：`ChapterEdgeFsm` 以独立 swipe 为主、overscroll 为辅；二次确认窗 2.5s；`chapterRequestId` 去重。
- **方向映射**：统一 r2l / reverse 物理滑动语义。
- **回滚**：构建可注入 `READER_LEGACY_GESTURE_ROUTING=true` 恢复旧路径。

### 安装

- Android：优先安装 `CopyManga-flutter-1.0.12-arm64-v8a.apk`
- iOS：unsigned IPA 由 Actions 产出后，用 Sideloadly 等重签侧载（免费账号约 7 天）

详见 `CHANGELOG.md` 与 `docs/reader_gesture_architecture.md`。
