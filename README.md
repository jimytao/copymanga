# CopyMangaWeb

拷贝漫画第三方 Android 客户端，基于 WebView 封装官方 H5 页面，强化阅读器与下载体验。

> Fork 自 [fumiama/copymanga (web branch)](https://github.com/fumiama/copymanga/tree/web)。  
> 当前活跃开发分支：[`re_build`](https://github.com/jimytao/copymanga/tree/re_build)

---

## 安装

在 [Releases](https://github.com/jimytao/copymanga/releases) 页面下载最新 APK，允许「安装未知来源应用」后直接安装。

- 最低系统要求：Android 6.0（API 23）
- **首次安装本 fork 版本**：需先卸载原版或其他签名的旧版本，再安装（签名不同，无法直接覆盖）
- 从 v1.5.4 起，后续版本均使用同一签名，可直接覆盖升级

---

## 功能

### 阅读器
- **三种阅读模式**：横向翻页 / 纵向翻页 / 条漫连续滚动
- **翻页方向**：左→右 / 右→左，切换后即时生效
- **页面跳转**：拖动进度条直接跳到任意页；点击页码数字可手动输入
- **动画开关**：VP 翻页动画可独立开关
- **音量键翻页**：横/纵模式翻页，条漫模式滚动 4/5 屏高
- **图片预加载**：VP 模式前后各预加载 5 页，单页模式向后预加载 10 张

### 下载
- 章节下载，本地保存为 ZIP 格式（无压缩，直接存原图）
- 下载列表管理，支持本地离线阅读

### 其他
- 深色模式、隐藏状态栏、异形屏适配
- 自动探测最快可用域名，后台异步更新

---

## 架构说明

本应用是 **WebView 封装器**，不直接调用拷贝漫画 API，而是通过操控 H5 页面来获取数据。

### 双 WebView 设计

\`\`\`
用户可见 WebView (i.js)          隐藏 WebView (h.js)
  ↓ 用户点击章节                   ↓ 加载同一章节的 PC 版
  GM.loadComic() ───────────────→ 自动滚动触发懒加载
                                   收集所有 img[data-src]
  ViewMangaActivity ←──────────── GM.loadChapter(图片列表)
\`\`\`

- **可见 WebView**：加载移动版网站，注入 \`i.js\`，供用户正常浏览
- **隐藏 WebView**：以 PC UA 加载相同页面，注入 \`h.js\` 自动滚动收集完整图片 URL
- 章节图片 URL 全部收集完毕后，才打开阅读器（即进度条 \`xx/xxx\` 期间所做的事）

### JS ↔ Kotlin 通信

| 方向 | 接口 | 作用 |
|------|------|------|
| \`i.js\` → Kotlin | \`JS.kt\`（注册为 \`GM\`）| 触发漫画/章节加载、设置面板等 |
| \`h.js\` → Kotlin | \`JSHidden.kt\`（注册为 \`GM\`）| 上报图片列表、加载进度 |

### 阅读器模式

| 模式 | 实现 | 备注 |
|------|------|------|
| 横向 / 纵向 | \`ViewPager2\` | 支持动画、r2l、offscreenPageLimit=5 |
| 单页（无动画）| \`ImageView\` | 手动 Glide 加载，向后预加载 10 张 |
| 条漫 | \`RecyclerView\` + \`LinearLayoutManager\` | 宽度撑满，滚动停止时同步页码 |

---

## 免责声明

本应用基于官方 H5 页面展示内容，作者不对应用内呈现的任何内容负责。仅供学习交流使用。
