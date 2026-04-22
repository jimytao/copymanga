## 修复与改进

### 🐛 修复后台图片 URL 加载完全失效的根本原因
- **根因**：`WebView.loadUrl("javascript:...")` 会将多行脚本压平为单行，导致 `h.js` 中的 `//` 单行注释把其后所有内容（包括闭合括号）全部注释掉，引发 `SyntaxError: Unexpected end of input`，脚本在解析阶段就崩溃，`try...catch` 也无法捕获，表现为静默失败。
- **修复**：删除 `h.js` 中所有 `//` 单行注释，彻底消除该隐患。

### 🔧 兼容性修复（h.js）
- 将 `let`/`const` 全部改为 `var`，将可选链 `?.` 和空值合并 `??` 改为兼容写法，确保在较旧 Android WebView 版本上不出现语法错误。

### 🛡️ i.js 防崩溃
- `clickClassCenter` 访问 DOM 前加元素存在性校验，避免 `comicContentPopupImageItem` 不存在时抛出 TypeError 导致后续 `GM.loadComic()` 永远无法执行。

### 📊 加载进度显示修正
- 进度上报从读取网站 DOM 的 `.comicIndex`（基于滚动视口，在隐藏 WebView 中严重滞后）改为直接统计已获取到 `data-src` 的图片数，进度条现在与实际加载进度一致。

### 🌙 暗色模式背景色适配
- 启动时和页面导航时，根据 `dark_mode` 设置同步给两个 WebView 设置背景色，消除暗色模式下的白底闪烁。
- 新增 `onPageCommitVisible` 回调，在页面第一帧提交时立即注入暗色滤镜，进一步缩短白底可见时间。
- JS 注入方式从 `loadUrl("javascript:...")` 改为 `evaluateJavascript`，更规范，不产生多余浏览历史。
