## Flutter v1.0.7

- 阅读器点击分区翻页（横向三分区随右开本对调；纵/条漫上下区 + 中央菜单）
- 横/纵捏合与双击缩放；优化翻页与缩放手势冲突，左右滑更跟手
- 条漫滑到底/顶二次确认切章修复
- 阅读器内切章同步表页 SPA 历史
- iOS 支持音量键翻页（系统音量观察方案）

### Android APK（按 ABI 分包）

| 文件 | 适用 |
|------|------|
| `CopyManga-flutter-1.0.7-arm64-v8a.apk` | 绝大多数真机（推荐） |
| `CopyManga-flutter-1.0.7-armeabi-v7a.apk` | 较老 32 位机 |
| `CopyManga-flutter-1.0.7-x86_64.apk` | 模拟器 |

### iOS

推送 tag `flutter-v1.0.7` 后由 GitHub Actions 产出未签名 IPA，可用 Sideloadly 等重签侧载（免费账号约 7 天需重签）。
