# CopyManga Kotlin 变更记录

> 本文件只记录 **Kotlin 原生版**（分支 `re_build` / Tag `v*`）。  
> Flutter 跨平台版见 `../copymanga_flutter/CHANGELOG.md`。

---

## 2026-08-22 — v1.5.17：域名更新与 2026copy.com 恢复

- **源站清理与域名核验**：对网络上各类备选域名进行自动化 HTTP/HTML 实测核验。
- **保留与新增有效源**：保留确认可正常打开拷贝漫画主页的 `copy3000.com`（`https://www.copy3000.com`）、`2026copy.com`（`https://www.2026copy.com`）、官方公告的大陆无障碍地址 `copy4000.com`（`https://www.copy4000.com`）与 `mangacopy.com`（`https://www.mangacopy.com`）。
- **移除失效源**：移除连接被重置/失效的 `copymanga.site`，以及广告/域名停靠类无效页面。

---

## 2026-08-01 — v1.5.16：边界二次确认换章 + 点击分区对齐

- **共享状态机**：抽出 `ChapterEdgeGuard` / `EdgeGestureGate`；`ViewMangaActivity` 持有唯一 `PagesManager`，点击 / 滑动 / 音量共用确认态。
- **音量键边界换章**：首末页同向再按两次对应音量键即可换章（文案「再次按下加载上/下一章」）；页内行为不变（条漫仍滚 4/5 屏）；忽略长按 repeat。
- **滑动二次确认**：横/纵 ViewPager2 与条漫列表越界拖动，一次手指手势只计一次；文案「再次滑动…」；无邻章首次即「已经到头了~」。
- **滑动防误触**：仅在「已在边界且该方向不可再滚」时计数；放大中不触发；翻到末页的同一次滑动不误计确认。
- **点击分区**：横向左中右（r2l 对调）；纵向改为上中下（中央菜单矩形，中带左右无效）；条漫仍仅点按出菜单。
- **i.js**：详情/章节顶栏返回优先 `history.back()`，失败回落 `lastBrowseUrl`；已同步 Flutter `assets/js/i.js`。
- **单测**：`ChapterEdgeGuard` / `EdgeGestureGate` / `ReaderTapClassifier` / `ChapterEdgeHint` JVM 单测。
- **版本**：`1.5.16` / versionCode `29`。

---


## 2026-07-19 — v1.5.15：撤销表 H5 切章同步

- **回退切章逻辑**：撤销 v1.5.14 新增的表 H5 静默同步与目标章节直接 `loadUrl`，恢复 v1.5.13 的页面控件触发方式。
- **修复下一章跳主页**：阅读器切章不再使用隐藏页返回的章节 URL 直接导航可见 WebView。
- **预取命中**：仅替换阅读器章节数据，不再改动后台可见 H5 的地址和状态。
- **版本**：`1.5.15` / versionCode `28`。

---

## 2026-07-19 — v1.5.14：切章表 H5 阅读进度同步

- **预取命中**也会静默同步可见 WebView 到目标章节（`loadVisibleUrlQuiet`），避免退出阅读器后详情仍显示旧话。
- **无预取切章**改为优先 `loadUrl(目标章)`，控件缺失时不再只靠 `clickClass`。
- `JS.loadComic` 尊重 `suppressLoadComic`，避免进度同步时重复触发隐藏 WebView 收图。
- **竞态**：`consumePrefetchedData` 仅在结果就绪时取走；未命中时 `abandonPrefetch` 丢弃迟到 `loadChapter`，避免双开阅读器。
- 源站列表：`2025copy.com` → `www.copymanga.site`（与 Flutter 对齐）。

---

## 2026-07-19 — v1.5.13：断点续读体验优化

- **看完即清零**：退出章节时若已读到最后一页（容忍一页误差），清除该章断点，下次从第 1 页开始；只有「读到一半」的章节才恢复进度。
- **恢复提示**：跳回断点时 Toast「已跳转至上次阅读的第 X 页」。

---

## 2026-07-07 — v1.5.12：阅读体验全面优化

### 新功能

- **断点续读**：每次退出章节自动记住当前页码，下次打开同一章节直接跳回上次位置（本地 ZIP 离线阅读同样支持）。
- **章节无缝预加载**：阅读到当前章节 80% 时，后台静默预取下一章图片列表；点击"下一章"时直接进入，无需等待收图进度条。
- **下载完成通知**：所有选中章节下载完毕后发送系统通知，点击通知直接跳转下载列表。

### 体验改进

- **图片卡加载修复**：引入 OkHttp 替换 Glide 默认 HTTP 层（`retryOnConnectionFailure=true`，连接超时 8s，读取超时 15s，连接池 8 条）；图片加载失败时自动最多重试 2 次（1.5s / 3s 退避间隔），彻底解决"前后页已加载、就这张卡住"问题。
- **VP 预加载并发数收窄**：`offscreenPageLimit` 从 5 降至 3（共 6 张同时请求→4 张），减少 CDN 连接竞争，提升每张图的有效带宽。
- **移除下载 10 秒强制等待**：章节 URL 收集改为信号量精确等待（`awaitAllUrlsCollected`），收集完成即刻开始下载，不再浪费最多 10 秒。

### 网络线路

- **新增第四备用源 `2025copy.com`**：原有三源（copy3000 / 2026copy / mangacopy）基础上增加 `https://2025copy.com`，测速时自动纳入评分；手动选源列表同步更新。

### 稳定性修复

- **`PropertiesTools` 并发安全**：`get`/`set` 加 `@Synchronized`，消除阅读器与下载同时修改设置时的竞态。
- **预加载与下载回调隔离**：`callViewManga` 中 `saveUrlsOnly`（下载模式）优先级高于 `isPrefetching`，保证后台下载章节 URL 收集不被预加载逻辑误拦截；预加载期间同步屏蔽 loading 弹窗和 FAB 抖动。
- **预加载超时自动重置**：若 h.js 60 秒内未回调（网络失败等），自动清除 `isPrefetching` 标志，不阻塞后续正常章节加载。
- **图片重试 Activity 生命周期守卫**：Activity 销毁/退出后 postDelayed 回调静默取消，不再抛 `IllegalArgumentException`。

---

## 2026-07-06 — v1.5.11：更新域名 + 多项鲁棒性强化

### 域名更新
- **替换失效域名**：移除已无法访问的 `copy20.com`，替换为官方公告的新大陆访问地址 `www.copy3000.com`（`mangacopy.com` 与 `2026copy.com` 保留，三源均已通过 ping 与内容验证）。

### 崩溃修复
- **`MangaDlTools.kt`**：`getImgsCountByHash`、`setChapterImages`、`dlChapterAndPackIntoZip` 三处 `p[hash].toInt()` 改为 `toIntOrNull()` + 安全跳过，防止 hash 文件损坏或章节映射丢失时抛出 `NumberFormatException` 崩溃。
- **`MainActivity.kt`**：`callViewManga` 新增 `listChapter.size < 3` 前置检查，防止 JS 侧传来的内容行数不足时访问越界索引崩溃。
- **`JS.kt`**：`loadComic` 两个 URL 分支均不匹配时不再向 WebView 传递空字符串，杜绝 `loadHiddenUrl("")` 触发未定义行为。

### 逻辑与稳定性强化
- **`MainHandler.kt`** + **`MainActivity.kt`**：新增 `MainHandler.clear()` 方法（dismiss + null 对话框），并在 `MainActivity.onDestroy` 中调用，防止 Activity 销毁后 loading dialog 引发 window leak。
- **`SettingsActivity.kt`**：改继承 `AppCompatActivity`（原为裸 `Activity`），与其余 Activity 主题链保持一致；`getCacheSizeText` 加 try/catch，避免存储权限异常导致设置页崩溃。
- **`ViewMangaActivity.kt`**：`onWindowFocusChanged` 在 API 30+ 改用 `WindowInsetsController`，弃用 `systemUiVisibility`；低版本保留原路径并加 `@Suppress`。
- **`UrlManager.kt`**：`activeUrl` 加 `@Volatile`，保证 IO 线程写入对主线程立即可见，消除测速与主线程读取之间的可见性竞态。
- **`DlActivity.kt`**：`comicName`、`json` 伴生字段加 `@Volatile`，消除下载流程中的跨线程竞态。

## 2026-04-29 — 修复多处安全与稳定性 Bug

- **关闭 Release 调试接口**：`MainActivity.kt` 将 `setWebContentsDebuggingEnabled(true)` 改为 `setWebContentsDebuggingEnabled(BuildConfig.DEBUG)`，release 包不再暴露 WebView 调试端口。
- **文件选择越界与丢回调**：`MainActivity.kt` 将 `0..clipData.itemCount` 改为 `0 until clipData.itemCount` 防止最后一项越界；移除仅在 `dataString != null` 时才回调的错误条件，clipData 场景现在也能正确回传结果。
- **阅读器进度除零保护**：`ViewMangaActivity.kt` 的 `updateSeekProgress()` 新增 `if (count == 0) return`，避免章节数据为空时崩溃。
- **后台线程 startActivity**：`DlActivity.kt` 将子线程中的 `callVM()` 改为 `runOnUiThread { callVM(...) }`，保证 Activity 跳转在主线程执行。
- **下载 Semaphore 超时**：`MangaDlTools.kt` 将 `sem.acquire()` 改为 `sem.tryAcquire(30, TimeUnit.SECONDS)`，回调丢失时最多等待 30 秒后放弃，不再永久阻塞。
- **ConnectivityManager 安全转换**：`ToolsBox.kt` 将强制 `as ConnectivityManager` 改为 `as?` 并在 null 时提前返回空字符串，避免弱引用失效导致的类型转换异常。

## 2026-04-26 — 修复阅读模式切换时阅读进度丢失问题

- **问题描述**：在横向/竖向/条漫模式之间切换时，本章节的阅读进度会被重置，导致用户从例如第 5 页直接跳转回第 1 页。
- **修复**：在 `ViewMangaActivity.kt` 的 `prepareIdBtVH` 中，在更改阅读模式之前记录当前的 `pageNum`。同时更新了 `applyReadMode` 方法的签名以接收 `currentPage` 参数，并在应用新模式界面后立即恢复并更新阅读进度，确保模式切换体验无缝衔接。

## 2026-04-24 — 移除应用内自动更新与安装权限以通过 Play Protect 审查

- **移除自动更新下载**：删除 `Updater.kt` 中的应用内下载与静默调起安装逻辑，此行为会被 Google Play Protect 判定为高风险特征。
- **移除危险权限**：从 `AndroidManifest.xml` 中删除 `android.permission.REQUEST_INSTALL_PACKAGES` 权限申请。
- **关联清理**：移除 `MainActivity.kt` 中对 `Updater` 的相关引用。

## 2026-04-23 — 修复条漫模式图片模糊

- **根本原因**：`WebtoonAdapter.onBindViewHolder` 调用 Glide 时未指定目标尺寸。`page_webtoon_imgview.xml` 的 `ImageView` 高度为 `wrap_content`，RecyclerView 在 `onBindViewHolder` 阶段 View 高度尚为 0，Glide 以该尺寸为目标执行下采样，导致解码出极低分辨率的 Bitmap，显示时被拉伸变模糊。横向/纵向模式使用 `ScaleImageView`（`match_parent × match_parent`），尺寸确定，Glide 采样正确，故始终清晰。
- **修复 `ViewMangaActivity.kt`**：在 `WebtoonAdapter.onBindViewHolder` 的 Glide 调用链中加入 `.override(Target.SIZE_ORIGINAL)`，强制以图片原始分辨率解码，完全跳过基于 View 尺寸的下采样逻辑；同步添加 `import com.bumptech.glide.request.target.Target`。
- **修复 `page_webtoon_imgview.xml`**：补充 `android:scaleType="fitCenter"`，与 `adjustViewBounds="true"` 行为对齐，确保 Glide 加载完成后图片正确缩放铺满宽度。

## 2026-04-23 — 源站测速升级 & h.js 回退路线整理

- **记录本轮收图问题的结论**：本轮调试先后尝试了“确认驱动逐张推进”“统一真实图片 URL 解析缓存”“PC DOM 总数推断增强”等方案，虽然理论上更严谨，但实测持续出现“进度条卡在 3-5 张、阅读器只收到极少图片”的回归。结合用户反馈与多轮实机验证，当前结论是：隐藏 PC WebView 的整体来源链路没有错，真正的问题在于后续重构偏离了旧版网站懒加载节奏，不能继续在确认驱动模型上堆补丁。
- **正式回退 `h.js` 收图主模型到旧版连续滚动结构**：将 `smoothLoadChapter()` 恢复为接近 `v1.5.7` 的 `requestAnimationFrame + scrollBy + countUrls + allDataSrcReady` 主流程，删除 `resolvedUrls`、`getResolvedImageUrl`、`startConfirmDriven`、`parseTotalCount` 等本轮实验性逻辑，仅保留已验证必要的 `toMobileUrl()` 修复，确保阅读器底部上一章/下一章按钮继续沿用正确的移动端 URL 链路。
- **最小化补充“到底脱困”机制**：在旧版滚动模型基础上新增底部补滚逻辑——当隐藏 PC WebView 已滚到底部但 `loadedCount < totalCount` 且连续多轮无增长时，先执行一次轻微上抬，再执行一次向下压回，目的是重新触发章节页的懒加载观察器。该补丁刻意不改变主收图模型，只解决旧版偶发“到底后卡住”的问题。
- **记录换章按钮的最终可靠链路**：阅读器底部“上一章/下一章”按钮不再尝试 `loadVisibleUrl(url)` 直接跳转，而统一改为复用 `PagesManager.openAdjacentChapter(goNext)`，内部通过 `javascript:invoke.clickClass("comicControlBottomTopClick", index)` 触发站内 SPA 按钮点击，与双击换章完全共用同一入口，修复了此前跳回首页的问题。
- **源站测速从“首页可达”升级为“阅读相关评分”**：`UrlManager.probe()` 旧版只对 `/favicon.ico` 发 `HEAD` 请求，无法反映章节页真实加载体验。现升级为同时探测首页静态资源与 `/comic` 漫画页响应时间，按加权分数选择当前 `activeUrl`，并把每个候选域名的首页耗时、漫画页耗时、最终加载档位汇总成摘要写入设置页，便于后续确认究竟是哪个源在拖慢隐藏 PC WebView 的懒加载节奏。
- **引入按源加载档位**：根据测速结果与域名特征为当前源生成 `normal` / `conservative` 档位，并在 `WebViewClient` 注入页面脚本前写入 `window.__CM_SOURCE_PROFILE`。`h.js` 保持旧版滚动结构不变，只按档位微调 `MIN_SPEED`、`MAX_SPEED`、提速/降速幅度和底部补滚节奏，让慢源（尤其疑似更容易抖动的 `mangacopy` 类源）自动使用更保守的滚动参数。
- **修正源评分与档位策略**：根据用户反馈，之前把 `mangacopy` 直接硬编码为 `conservative` 与真实体感不符，现已删除该偏置；档位只在漫画页探测明显偏慢时才降为 `conservative`。评分公式也从简单偏向首页可达性改为更重视漫画入口响应，避免 `copy20`/`mangacopy` 因首页静态资源快而掩盖章节页实际更慢的问题。
- **新增手动选源能力**：设置页在“重新检测最快服务器”之外，新增“手动选择服务器”入口。列表中会展示每个候选源的名称、标注（例如 `2026copy` 标记为“中国大陆推荐”）、首页速度、漫画页延迟、综合评分与当前档位，方便用户结合自身地区与运营商手动选择最适合的线路。
- **区分自动模式与手动模式，避免登录态被跨域打断**：自动测速结果仍会缓存，但应用启动时默认沿用当前缓存源，不会每次打开都自动强制切换域名，避免跨域导致登录状态/Cookie 丢失。手动选源使用独立的 override 状态保存，不覆盖自动测速缓存；恢复自动模式后可继续回到上次自动推荐的源。
- **补充加载卡顿提示**：当隐藏 WebView 在章节加载过程中连续超过 1 秒无新增图片 URL 时，加载弹窗文本会追加“网络较慢，可到设置里重测/切换源”提示，引导用户优先通过源切换排查网络/线路问题，而不是误以为阅读器主逻辑再次损坏。
- **地区标签彻底改为纯展示，不再参与自动优先级**：`2026copy` 的“中国大陆推荐”只保留为说明文案，不再赋予任何排序优势。自动选源现在明确要求对 `2026copy`、`copy20`、`mangacopy` 一视同仁，仅按真实测速与章节基准结果评分。
- **引入章节级基准评分，优先“能否完整读完”而不是“首页是否更快”**：根据用户提供的两个真实章节（一个曾在 70+ 页附近卡住、一个长期稳定）为每个候选源做基准探测。新评分先看章节完整度，再看章节响应速度，最后才参考 `/comic` 与首页延迟，统一折算为 100 分制，避免再次出现“首页更快但章节更差”的错误排序。
- **基准章节失败即降档，保证手动硬选也尽量可用**：任一候选源在基准章节中出现 FAIL、完整率明显不足或响应过慢时，会在本轮检测内被标记为 `conservative`，让 `h.js` 自动采用更保守的滚动/脱困节奏，降低手动选中慢源时的卡顿概率。
- **降档改为“一次性”状态，不继承历史污染**：每次重新检测或查看源状态前，都会先把各源视为 `normal`，再根据本轮基准结果重新决定是否降档。这样不会发生“上次测坏了，这次恢复后仍被永久保守处理”的累积偏置，行为上等价于每轮检测前先清空档位状态。
- **放弃自动章节评分与自动降档，回到更可控的主页延迟排序**：由于真实章节基准在多源环境下过于容易出现统一 FAIL，导致所有候选源一起被误伤，这版移除了章节级评分、100 分制、基准失败自动降档等复杂逻辑。服务器检测重新简化为仅测首页延迟，并按延迟从快到慢排序；自动模式直接选择排序第一的源。
- **把挡位选择权完全交给用户**：`normal` / `conservative` 不再由检测逻辑自动决定，而是新增设置项让用户手动切换。说明文案也同步补充：`normal` 滚动更积极，适合大多数正常源；`conservative` 更保守、更稳，适合慢源或出现卡顿时手动切换。
- **设置页文案与展示同步收敛**：手动选源列表不再展示评分、漫画页延迟或基准章节结果，只展示主页延迟与排序名次；网络设置说明更新为“检测仅按主页延迟排序，挡位由用户自己决定”，避免设置页继续暗示存在自动智能评分。

## 2026-04-23 — h.js 收图与阅读器换章链路二次修正

- **修复“进度条跑满但阅读器只有 4-5 张图”**：首次确认驱动重构仍沿用了 `img.dataset.src` 单一字段假设，导致隐藏 WebView 虽然完成了滚动，但 `finish()` 阶段重新扫 DOM 时只能拿到极少数真正落在 `dataset.src` 上的图片 URL，Kotlin 侧收到的数组天然只有 4-5 项。现在在 `h.js` 中新增统一的真实图片地址解析函数，按 `currentSrc` → `src` → `dataset.src` → `dataset.original` → `data-src` / `data-original` / `src attribute` 的顺序解析，并过滤 `data:`、`blob:`、空串等无效值。
- **统一“推进条件”和“最终输出条件”**：新增 `resolvedUrls[]` 缓存，`startConfirmDriven()` 在推进过程中持续全量补扫 DOM，将每张图已解析到的真实 URL 直接写入缓存；进度条显示也改为统计 `resolvedUrls` 中的有效数量。`finish()` 不再临时重新读 `img.dataset.src`，而是直接输出缓存结果，避免“滚动阶段看到加载好了，finish 阶段却重新读丢”的竞态。
- **补扫与收敛策略**：新增 `scanResolvedUrls()` 和 `countResolvedUrls()`，每轮 tick 与 finish 前都统一补扫一次全部图片节点，确保那些稍晚才把真实地址写入 `src/currentSrc` 的图片不会因为时序问题漏收。
- **修复阅读器底部“上一章/下一章”仍跳回首页**：进一步调研确认，真正可靠的换章链路从来不是 `loadVisibleUrl(url)` 直接让可见 WebView 跳 URL，而是 `PagesManager` 里已经稳定工作的 `javascript:invoke.clickClass("comicControlBottomTopClick", index)` 站内点击机制。之前的底部按钮与双击换章虽然目标一致，但实现不同，仍然属于两套链路。
- **链路统一**：在 `PagesManager` 中抽出 `openAdjacentChapter(goNext)` 公共方法，内部直接复用站内按钮点击脚本并关闭当前阅读器；`ViewMangaActivity.prepareChapterNavButtons()` 改为调用该方法，底部按钮与双击换章现在真正共用同一入口，不再自己执行 `loadVisibleUrl()`。

## 2026-04-23 — 系统栏/手势条适配修正 & 下一章/上一章按钮修复

- **Insets 适配重写** (`MainActivity.onCreate`)：将底部 padding 来源从 `tappableElement` 单一类型改为 `systemBars()` 与 `tappableElement`、`displayCutout` 取 max。原逻辑在纯手势导航 + 半透明手势条（小米 HyperOS、部分 Carbon ROM）场景下 `tappableElement.bottom=0`，导致 WebView 内容被手势条/导航栏遮挡，现已修复 mi6x (A10) 底部 tab 文字截断、K50 (A14 HyperOS) 手势条叠加等问题。
- **修复阅读器下一章/上一章按钮不同步阅读进度（Issue #3）**：
  - 调试过程：方案 A（同时驱动可见+隐藏 WebView）导致 Activity 叠加 bug 已废弃；方案 B（`loadVisibleUrl` 只导航可见 WebView）理论正确但实测无效，排查后定位根本原因如下。
  - 根本原因：`h.js` 运行在 PC UA 的隐藏 WebView 中，从 PC 页面 `<a href>` 取到的 `nextChapter`/`prevChapter` 是 PC 格式 URL（`https://域名/comic/{manga}/chapter/{uuid}`）。`loadVisibleUrl` 把该 URL 加载到移动端 WebView 后，URL 路径不含 `/comicContent/`，`i.js` 的 `urlChangeListener` 每秒轮询时无法匹配该分支，隐藏 WebView 永远不被触发，阅读器不会打开。
  - 修复：在 `h.js` 的 `finish()` 函数中新增 `toMobileUrl()` 辅助函数，将 PC 格式 URL 转换为移动端 H5 格式（`/comicContent/{manga}/{uuid}`）后再写入结果字符串传给 Kotlin。按钮点击后 `loadVisibleUrl` 加载移动端 URL，`i.js` 的 `modify()` 命中 `/comicContent/` 分支，调用 `invoke.loadChapter()` → `GM.loadComic()` → 隐藏 WebView 收图 → 打开阅读器，与用户双击换章完全走同一条路径。

## 2026-04-23 — h.js 滚动加载架构重构：盲目滚动 → 确认驱动

- **问题定位**：部分小章节（50-80页）进度条卡在中间某数字不再增加。根本原因是原方案本质为"盲目速度滚动"：以 350px/帧高速 `scrollBy`，小章节页面矮，极快滚到底部，剩余几张图的 `IntersectionObserver` 懒加载来不及响应；到底后速度自适应器虽然降速，但页面已无法再滚，懒加载永远不再触发，`isFullyLoaded` 条件永远无法满足，脚本死循环空转。
- **架构决策**：彻底废弃"速度驱动"模型，改为"确认驱动"模型——不再关心滚动速度，转而逐张明确确认每张图的 `data-src` 已被触发后才推进。
- **删除的旧逻辑**（整个 `smoothLoadChapter` 重写）：
  - 删除 `currentSpeed`、`MIN_SPEED`（200）、`MAX_SPEED`（600）、`SPEED_ADJUST_INTERVAL`、`speedAdjustCooldown` — 速度自适应算法全部移除
  - 删除 `prevHeight`、`atBottom` 检测 — 不再需要判断是否到底
  - 删除 `isFullyLoaded`、`waitStartTime`、`allDataSrcReady` — 完成判定逻辑整体替换
  - 删除 `countUrls` 函数 — 进度改为直接用 `curIdx` 计数
  - 删除 `prevUrlCount`、`urlDelta` — 速度调节依据，随速度逻辑一并删除
  - 删除 `step(timestamp)` + `requestTick()` 的定时帧循环结构
- **新增逻辑**：
  - 新增 `pollForTotalCount(startTime)`：以 100ms 间隔轮询 `.comicCount` DOM，最多等待 3 秒；超时则退化为以 `items.length` 作为总数（兼容无 comicCount 的章节）
  - 新增 `startConfirmDriven(totalCount)`：维护 `curIdx` 游标，对第 `curIdx` 张图调用 `scrollIntoView({block:"center"})` 将其带入视口，等待 `img.dataset.src` 出现后 `curIdx++` 继续下一张
  - 新增动态间隔：`nextWait = actualWait × 0.8`，clamp 在 80ms-1500ms 之间；网速快时间隔自动收缩，网速慢时自动拉长，节奏不规则，相比原 16ms 定时高频更不像爬虫
  - 新增单张图重试：等待超过 1500ms 时重新 `scrollIntoView` 一次；二次超时则跳过该张继续（极端网络降级但不卡死）
  - 新增 8 秒全局超时兜底：防止极端异常导致无限循环
  - `toMobileUrl`、`finish` 函数逻辑保留，整合进新结构

## 2026-04-23 — 死代码清理

- **删除 `fab_settings` 按钮**（`activity_main.xml` 第 53-69 行）：该按钮 `visibility` 绑定 `mainViewModel.settingsFabVisibility`，该字段初始值为 `View.GONE` 且全局从未被设为 `VISIBLE`，即永远不可见；其 `android:onClick="onSettingsFabClicked"` 指向的方法已在 2026-04-17 随 FAB 设置入口废弃时删除，若按钮意外显示会直接崩溃。同步删除 `MainViewModel.kt` 中的 `settingsFabVisibility: MutableLiveData` 字段。
- **删除 `PagesManager.kt` 中的 `pnHint` 死变量**：`val pnHint = if(!goNext) -2 else -1` 赋值后在同一作用域内从未被读取，其注释"通过下次 WebView 触发 callViewManga 时的 Intent 传递"所描述的机制实际从未实现，是规划中未完成的残留。
- **删除 `WebViewClient.kt` 的 `shouldInterceptRequest` 无效覆写**：该方法体仅有 `request?.requestHeaders?.set("Access-Control-Allow-Origin", "*")` 一行，但 `WebResourceRequest.requestHeaders` 按 Android 文档返回不可修改的 Map，`set` 调用在运行时静默抛出 `UnsupportedOperationException` 或被忽略，对实际网络请求无任何影响。同步删除因此变为无用的 `import android.webkit.WebResourceRequest` 和 `import android.webkit.WebResourceResponse` 两行。

## 2026-04-22 — 深度暗色模式适配 & 消除启动/加载白闪 (v1.5.8)

- **应用启动白闪消除**：新增 `AppTheme.Dark` 和 `Theme.App.Starting.Dark` 主题；在 `MainActivity.onCreate` 最早期（`installSplashScreen` 之前）根据设置切换主题，确保从点击图标起整个窗口背景均为黑色。
- **原生强制暗黑 (Force Dark)**：引入 `androidx.webkit` 库，启用 WebView 原生 `FORCE_DARK` 支持，并采用 `USER_AGENT_DARKENING_ONLY` 激进策略，使浏览器内核在网页渲染初期即自动转为深色。
- **加载中白闪修正 (Logo页适配)**：在 `WebChromeClient.onProgressChanged` 中实现毫秒级探测，加载进度达 2% 时即提前注入暗色滤镜 CSS，解决了网站自带 Loading 界面（带 Logo 的白色页）无法被后期注入覆盖的问题。
- **UI 状态栏适配**：使用 `WindowInsetsControllerCompat` 动态切换状态栏图标颜色，确保在深色背景下状态栏图标清晰可见（白色）。
- **加载性能优化**（*已被 2026-04-23 确认驱动重构取代*）：`h.js` 引入智能限速算法，根据网页图片加载吞吐量动态调整后台模拟滚动跨度（自适应 200px-600px/帧），并使用 `requestAnimationFrame` 驱动，确保在不漏页的前提下达到最高抓取效率，同时降低 CPU 占用。
- **漫画 URL 提取策略重构**（*已被 2026-04-23 确认驱动重构取代*）：在 `h.js` 中彻底废弃依赖 DOM 滚动位置的旧逻辑，改为基于图片元素属性计数的全新模式，大幅提升了长章节后台预加载的稳定性和速度。
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

