## Flutter v1.0.8

- 条漫模式关闭点击翻页（保留中央轻点出/收菜单），避免滑动误触
- 纵向点击改为上/中/下三分区；菜单为居中小矩形，中带左右两侧无效
- 横向左/中/右三分区与右开本对调逻辑不变

### Android APK（按 ABI 分包）

| 文件 | 适用 |
|------|------|
| `CopyManga-flutter-1.0.8-arm64-v8a.apk` | 绝大多数真机（推荐） |
| `CopyManga-flutter-1.0.8-armeabi-v7a.apk` | 较老 32 位机 |
| `CopyManga-flutter-1.0.8-x86_64.apk` | 模拟器 |

### iOS

推送 tag `flutter-v1.0.8` 后由 GitHub Actions 产出未签名 IPA，可用 Sideloadly 等重签侧载（免费账号约 7 天需重签）。
