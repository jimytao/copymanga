## 2026-04-22 — 深度暗色模式适配 & 消除启动/加载白闪 (v1.5.8)

- **应用启动白闪消除**：新增 `AppTheme.Dark` 和 `Theme.App.Starting.Dark` 主题；在 `MainActivity.onCreate` 最早期（`installSplashScreen` 之前）根据设置切换主题，确保从点击图标起整个窗口背景均为黑色。
- **原生强制暗黑 (Force Dark)**：引入 `androidx.webkit` 库，启用 WebView 原生 `FORCE_DARK` 支持，并采用 `USER_AGENT_DARKENING_ONLY` 激进策略，使浏览器内核在网页渲染初期即自动转为深色。
- **加载中白闪修正 (Logo页适配)**：在 `WebChromeClient.onProgressChanged` 中实现毫秒级探测，加载进度达 2% 时即提前注入暗色滤镜 CSS，解决了网站自带 Loading 界面（带 Logo 的白色页）无法被后期注入覆盖的问题。
- **UI 状态栏适配**：使用 `WindowInsetsControllerCompat` 动态切换状态栏图标颜色，确保在深色背景下状态栏图标清晰可见（白色）。
- **镜像测速与秒开优化**：`UrlManager` 引入并发测速机制，自动选取最低延迟节点；配合 `MainActivity` 的后台异步更新策略，实现应用“秒开”而不必等待网络探测。
- **漫画 URL 提取策略重构**：在 `h.js` 中彻底废弃依赖 DOM 滚动位置的旧逻辑，改为基于图片元素属性计数的全新模式，大幅提升了长章节后台预加载的稳定性和速度。
- **健壮性提升**：优化 CSS 注入脚本，支持在 `document.head` 尚未生成时自动挂载至 `documentElement`，确保暗色滤镜应用无死角。

## 2026-04-22 — 暗色模式背景色适配 & 加载进度显示修正 (v1.5.7)

- 暗色模式启动白闪：在 `onCreate` 中于 WebView 加载之前，根据 `dark_mode` 设置同步给 `mBinding.w` 和 `mBinding.wh` 设置背景色；切换主题的 `applyDarkMode()` 也同步更新两个 WebView 的背景色，消除启动和页面导航时的白底闪烁。
- 更早注入暗色 CSS：新增 `onPageCommitVisible` 回调，在页面第一帧提交时立即通过 `evaluateJavascript` 注入暗色滤镜，不再等 `onPageFinished + 500ms`，进一步缩短暗色模式下内容白底可见时间。
- JS 注入方式改进：`onPageFinished` 中的脚本注入从 `loadUrl("javascript:...")` 改为 `evaluateJavascript`，避免产生多余的浏览历史条目。
- 加载进度显示修正：`h.js` 中进度上报从读取网站 DOM 的 `.comicIndex`（基于滚动视口，在隐藏 WebView 中严重滞后）改为直接统计 `countUrls()` 已获取到 `data-src` 的图片数，进度条与实际加载进度一致。

## 2026-04-22 — 修复 h.js 注入后完全不执行的根本问题

- 根因定位：`WebView.loadUrl("javascript:...")` 会将脚本压缩成单行传入，导致 `//` 单行注释会把其后所有内容（包括闭合大括号）全部注释掉，引发 `SyntaxError: Unexpected end of input`，整个脚本在解析阶段崩溃，`try...catch` 也无法捕获，表现为静默失败。
- 修复：删除 h.js 中所有 `//` 单行注释，彻底消除该隐患。
- 兼容性修复：将 h.js 中 `let`/`const` 改为 `var`，将可选链 `?.` 和空值合并 `??` 改为三元表达式，确保在较旧 Android WebView 上不出现语法错误。
- i.js 防崩溃：`clickClassCenter` 访问 DOM 前加 `length > index` 判断，避免 `comicContentPopupImageItem` 元素不存在时抛出 TypeError，导致紧随其后的 `GM.loadComic()` 永远无法被调用。
- 清理：移除调试阶段临时添加的 `GM.log()`、`Log.d/e("MyJSH")` 等日志调用及 `JSHidden.log()` 接口，恢复生产态代码。

## 2026-04-22 — 优化滚动加载逻辑，大幅提升进入阅读器速度

- 根因定位：旧版 `h.js` 在到底部后必须死等 `stableFrames` 帧（约 240ms）来确认是否加载完毕。网速慢时 240ms 不够导致漏图；如果将等待时间加长到 60 帧（1秒），则会在图片加载完后依然强制卡顿死等1秒，导致体验极差。
- 终极方案：引入总页数精确判定机制。脚本提取页面 `.comicCount` 作为总页数，当已加载的图量达标且获得 `data-src` 后，**瞬间完成**并进入阅读器，实现 0 毫秒等待。
- 极速回归：依赖精确的结束机制，不再怕过早到底部，将滚动速度恢复至极速 `800px/16ms`，大幅缩短长条漫滚动耗时。
- 异常兜底：保留 60 帧（约1秒）的超时判断作为 fallback 兜底，防止意外导致死循环。
- 稳定性修复：增加了防崩溃保护机制。修复了当 WebView 刚完成加载并注入 JS 时，部分 DOM 元素（如 `.comicCount`）尚未完全渲染导致的空指针报错，这解决了偶然出现的“后台加载完全不启动（假死）”的问题；同时将核心循环包入 `try...catch`，遇到意外异常会通过 Android Alert 弹窗直观提示错误行号，不再静默崩溃。

## 2026-04-22 — 主界面 edge-to-edge 重构，彻底消除旧机底部白色色块

- 根因定位：白色色块不是应用根布局背景，而是 `Theme.AppCompat.Light.NoActionBar` 的 DecorView 默认白底。主题原有 `windowTranslucentNavigation=false` 限定窗口不绘制到导航栏区域，加上 `navigationBarColor=transparent` 只让导航栏透明，透过去的仍是 DecorView 白底
- 方案：调用 `WindowCompat.setDecorFitsSystemWindows(window, false)` 让整个窗口 edge-to-edge，WebView 内容延伸到屏幕物理底部；删除 `styles.xml` 里阻挡 edge-to-edge 的 `windowTranslucentNavigation=false`
- Inset 简化：根布局 `fitsSystemWindows` 移除，改为统一监听 `OnApplyWindowInsets`；底/侧边采用 `tappableElement()` inset（仅有实体按钮时非零），不再依赖版本号或 `config_navBarInteractionMode` 等内部资源判断手势/按键模式
- 顶部：按 `max(statusBars, displayCutout)` 让位，覆盖普通状态栏和刘海/挖孔；状态栏隐藏时归零；`toggleStatusBar()` 触发 `requestApplyInsets` 实时刷新
- 色彩同步：`onCreate` 里根据 `dark_mode` 明确双向设置根布局背景色（黑/白），避免亮色模式下主题默认 MIUI 白色底泄漏
- 实机验证：MI 6X（MIUI 全屏手势，SDK 29）底部白条消除；Android 16 手势机型观感保持一致

## 2026-04-20 — 修复返回键不回退 WebView 历史

- MainActivity 返回键处理从废弃的 `onBackPressed()` 重写改为 `OnBackPressedCallback`，修复 Android 14+ Predictive Back Gesture 导致返回键直接退出 App 而非回退页面的问题

## 2026-04-17 — 阅读器体验持续改进

- 条漫模式点击屏幕可正常切换菜单栏显示/隐藏（WebtoonAdapter item 加 click listener → PagesManager.manageInfo）
- 条漫模式页码同步：RecyclerView 滚动停止时读取 findFirstVisibleItemPosition 更新 seekbar 和页码文字
- 条漫模式跳转生效：setPageNumber/getPageNumber 加 isWebtoon 分支，seekbar 拖动和手动输入均可跳页
- ToggleButton 文字顺序修正：isChecked 赋值必须在 text 之前，否则内部 syncTextState 会覆盖自定义文字（影响"纵向"/"条漫"标签）
- 页码文字（2/100）可点击，弹出数字输入框，支持直接输入或回车跳转；超出范围自动 clamp
- SeekBar 改为直接跳页：原逻辑每次只移动 ±1 页，改为根据进度直接计算目标页；单页模式拖动时只更新显示，松手后再加载图片
- 底部设置抽屉（infcard）与顶部栏同步：showSettings 触发 sendEmptyMessage(2)；MyHandler.delta 改为实时读取不缓存；prepareItems 等 layout 完成后用 infcard 实际高度作为滑出 delta
- VP 预加载提升至 offscreenPageLimit=5；单页模式向后预加载 10 张

## 2026-04-17 — 四项体验改进

- infcard（底部设置抽屉）现在与顶部栏同步显示/隐藏：`showSettings()` 新增 `sendEmptyMessage(2)`
- 翻页方向（←→）切换立即生效：重建 VP Adapter 并跳回当前页，不再需要重新打开
- 新增条漫模式：`idtbvh` 按钮改为三态循环（横向→纵向→条漫），条漫模式使用垂直 RecyclerView 连续滚动，图片宽度撑满屏幕；音量键在条漫模式下滚动 4/5 屏高
- 图片预加载提升：VP 模式设 `offscreenPageLimit=3`（前后各预加载 3 页）；单页模式在加载当前页时用 Glide 预加载前后共 3 张

## 2026-04-17 — 修复 4 个体验 bug

- i.js：移除对已删除方法 `GM.hideSettingsFab()` 的调用，避免每次页面加载产生静默 JS 异常
- ViewMangaActivity：`showPageNum` 设置从未被读取，页码始终显示；现在正确读取并控制 `inftxtprogress` 可见性
- SettingsActivity：探测域名后只重载了隐藏 WebView，主 WebView 仍停留旧域名；现在同步重载两个 WebView
- ViewMangaActivity + widget_infodrawer：`nextChapterUrl`/`previousChapterUrl` 已从 h.js 解析传入但从未使用；在设置抽屉底部加入「上一章」「下一章」按钮，无可用章节时自动置灰

## 2026-04-17 — 修复 h.js 章节名称丢失、null 崩溃及资源泄漏

- h.js：`JSON.constructor()` 创建的是 Function 对象，其 `name` 属性不可写，导致章节名称全部丢失；改用对象字面量 `{}`
- h.js：`smoothLoadChapter` 对 `comicContent`、`comicContent-next`、`comicContent-prev` 元素缺少 null 检查，页面结构异常时会 TypeError；加 null 守卫
- ViewMangaActivity：`getImgBitmap` 每次翻页都创建 `ZipFile` 但从不关闭，导致文件描述符耗尽；改用 `.use { }`
- DlListActivity：`checkZip` 中 `ZipInputStream` 如遇异常不会关闭；改用 `.use { }`

## 2026-04-17 — 修复阅读器翻页崩溃和快速点击问题（Issue #3）

- 修复 r2l + VP 动画模式下翻到边界页时 `currentItem` 越界导致的崩溃：在 `pageNum` setter 中用 `coerceIn(1, count)` 限制范围
- 修复竖向/动画模式下快速点击翻页导致重复跳页的问题：通过 `isPageTurning` 标志在 VP 滚动动画期间屏蔽额外输入

## 2026-04-17 — 清理 MainActivity.kt 合并残留

- 删除重复方法 `applyDarkMode`、`setStatusBarHidden`、`setTopOffset`（各出现两次，第二份为旧版本残留）
- 删除死代码 `showSettingsFab`、`hideSettingsFab`、`onSettingsFabClicked`（设置入口已改为 i.js DOM 注入，FAB 方式废弃）
