# CopyManga（Flutter）

拷贝漫画第三方客户端的 **Flutter 跨平台重写**（Android / iOS），与安卓原生 Kotlin 版（[`re_build` 分支](https://github.com/jimytao/copymanga/tree/re_build)）并行维护。

> 套壳官网 H5 + 双 WebView 收图，**不调用**已被封锁的官方 API。脚本 `i.js` / `h.js` 与 Kotlin 版同源复用。

| | Kotlin 原生版 | 本 Flutter 版 |
|--|---------------|---------------|
| 仓库分支 | `re_build` | **`flutter`** |
| Release Tag | `v1.5.x` | **`flutter-v1.0.0`** 起 |
| 包名 | `top.fumiama.copymangaweb` | `top.fumiama.copymanga_flutter`（可并装） |
| 发版 SOP | [`copymanga-src/workflow.md`](../copymanga-src/workflow.md)（本地） | [`workflow.md`](workflow.md)（本地） |
| 变更记录 | [`CHANGELOG.md`](../copymanga-src/CHANGELOG.md) | [`CHANGELOG.md`](CHANGELOG.md) |

最新安装包：[Releases · flutter-v*](https://github.com/jimytao/copymanga/releases)

---

## 安装

### Android

1. 在 [Releases](https://github.com/jimytao/copymanga/releases) 按 CPU 架构下载（**真机优先 `arm64-v8a`**）：
   - `CopyManga-flutter-x.y.z-arm64-v8a.apk`（推荐）
   - `CopyManga-flutter-x.y.z-armeabi-v7a.apk`（较老 32 位机）
   - `CopyManga-flutter-x.y.z-x86_64.apk`（模拟器）
2. 允许「安装未知来源应用」后安装
3. 若曾安装过早期 debug / 旧胖包且无法覆盖，先卸载再装

### iOS（侧载）

1. 下载同版本 `CopyManga-flutter-x.y.z-unsigned.ipa`
2. 用 [Sideloadly](https://sideloadly.io/) 等工具以自己的苹果账号重签安装
3. 设置 → 通用 → VPN 与设备管理 → 信任开发者  
4. 免费账号侧载通常约 **7 天**需重新签名

无 Mac 时 IPA 由 GitHub Actions 在推送 `flutter-v*` tag 后自动编译。

---

## 功能

- **双 WebView 收图**：可见页浏览手机站；隐藏页以 PC UA 收集章节图片（内联 WebView，避免 rAF 节流）
- **三种阅读模式**：横向（左开/右开）/ 纵向 / 条漫；横左中右三分区翻页；纵上中下三分区（菜单为居中小矩形，中带左右无效）；条漫仅中央点按出菜单，禁用点击翻页以免滑动误触
- **缩放**：横/纵捏合与双击放大；未缩放时不挂 InteractiveViewer，避免与翻页手势竞争；放大时锁定翻页
- **断点续读**：读到一半恢复并提示；看完清零
- **原地切章** + 80% 预取下一章 + 翻到头再滑/再点/再按音量键二次确认切章
- **批量下载**与「我的下载」（可拖动悬浮钮、离线上下章）
- **多域名测速**（正文校验）+ sticky 自动选源（首次最快，之后忠诚；失效或倒数且慢≥1s/2倍才换）+ 手动选源 + 缓存清理
- **设置入口**：点击主页底部导航的「我的」（用户个人中心），约 1 秒后页面顶部会自动插入「⚙ App扩展设置」条目，点击即可进入设置（管理线路源与测速、常驻隐藏状态栏、深色模式与缓存等）
- **全面屏适配（双击切换状态栏）**：主界面双击屏幕/网页空白处即可即时隐藏或显示系统状态栏，非常方便地适配各类挖孔、刘海等全面屏机型；设置中亦支持常驻隐藏
- **暗色模式**、页码跳转、音量键翻页与边界换章（Android / iOS）、无网引导离线
- **启动 Splash**：橙色品牌过渡页

---

## 架构（与原生版同构）

```
可见 WebView (i.js)                 隐藏 WebView (h.js)
  用户点章节                          PC UA 加载章节页
  GM.loadComic() ──────────────────→ 自动滚动收集图片
  ReaderPage ←────────────────────── GM.loadChapter(列表)
```

`assets/js/gm_shim.js` 把原生 `@JavascriptInterface GM` 映射到 `flutter_inappwebview` 的 `callHandler`，**i.js / h.js 无需改动**。改脚本时请与 Kotlin 版 `app/src/main/assets/` **双向同步**。

---

## 本地构建

```bash
flutter pub get
# Android：发版必须 split（禁止打无 --split-per-abi 的胖包）
flutter build apk --release --split-per-abi
flutter build ios --no-codesign      # 需 macOS；无 Mac 用 Actions
```


推送 Tag 触发 IPA：

```bash
git tag flutter-v1.0.1
git push origin flutter-v1.0.1
```

版本号唯一源：`pubspec.yaml` 的 `version: x.y.z+code`。细节见 `workflow.md`。

---

## 免责声明

本应用基于官方 H5 页面展示内容，作者不对应用内呈现的任何内容负责。仅供学习交流使用。
