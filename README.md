# copymanga_flutter

CopyManga 套壳阅读器的 Flutter 跨平台重写（Android / iOS），复刻原生 Kotlin 版
（`../copymanga-src`）的双 WebView 架构：

- **可见 WebView**：加载手机版站点，注入 `assets/js/i.js`，用户正常浏览；
- **隐藏 HeadlessInAppWebView**：以 PC User-Agent 加载章节页，注入 `assets/js/h.js`
  自动滚动收集图片 URL；
- **GM 桥**：`assets/js/gm_shim.js` 把原生版的 `@JavascriptInterface GM` 对象映射到
  `flutter_inappwebview` 的 `callHandler`，i.js / h.js 无需改动直接复用。

## 构建

```bash
flutter pub get
flutter build apk            # Android
flutter build ios --no-codesign   # iOS（需 macOS；无 Mac 用 GitHub Actions）
```

推送 `v*` 标签或手动触发 `.github/workflows/build-ios.yml` 可在 GitHub Actions
上产出未签名 IPA（Sideloadly / AltStore 侧载时重签）。

## 当前状态

- [x] 双 WebView 收图链路（在线阅读；隐藏 WebView 为内联真实控件，防 rAF 节流）
- [x] 三种阅读模式：横向翻页（右开/左开）、纵向翻页、条漫滚动
- [x] 断点续读（看完自动清零 + 恢复提示）；页码角标点按跳页
- [x] 阅读器内原地切换上/下一章；80% 静默预取；翻页到头再翻切章
- [x] 批量下载（详情页 FAB → 章节多选 → 串行收图 + 4 并发下图）
- [x] 我的下载两级浏览（漫画→章节）+ 离线上下章导航
- [x] 暗色模式（App 主题 + 双 WebView CSS 反色注入）
- [x] 图片预载（后 5 张）+ 失败退避自动重试
- [x] 音量键翻页（Android 平台通道）
- [x] 多域名测速（内容校验防停靠页）+ 手动/自动源模式 + 缓存管理
- [x] 网页加载进度条、JS 弹窗自动确认、双击隐藏状态栏、无网引导离线
- [ ] iOS 真机验证（音量键翻页仅 Android）
- [ ] 启动 SplashScreen 品牌化
