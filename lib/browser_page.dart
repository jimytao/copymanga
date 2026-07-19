import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator, rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chapter_data.dart';
import 'downloader.dart';
import 'download_select_page.dart';
import 'downloads_page.dart';
import 'reader_page.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'system_ui.dart';
import 'url_manager.dart';

const pcUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// 双击网页切换状态栏的注入脚本（原生版用 GestureDetector，这里在页面内监听）
const _dblTapJs = """
if (!window.__cm_dbltap) {
  window.__cm_dbltap = true;
  document.addEventListener('dblclick', function () {
    if (window.GM && GM.toggleStatusBar) GM.toggleStatusBar();
    else if (window.flutter_inappwebview) window.flutter_inappwebview.callHandler('toggleStatusBar');
  });
}
""";

/// 主页面：可见 WebView 浏览手机版站点，隐藏 WebView 用 PC UA 收图。
/// 两个 WebView 都是真实控件叠放（隐藏的在底层被完全遮住），
/// 保证隐藏页面的 requestAnimationFrame 全速运行。
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? _visibleController;
  InAppWebViewController? _hiddenController;

  late final String _gmShim;
  late final String _iJs;
  late final String _hJs;
  bool _assetsLoaded = false;

  // 顶部网页加载进度条
  int _webProgress = 100;

  // 收图进度（浏览页浮层）
  bool _loadingChapter = false;
  String _loadingProgress = '';
  Timer? _stallTimer;
  DateTime _lastProgressAt = DateTime.now();

  // 章节流转状态机
  bool _pendingOpen = false;
  String? _pendingUrl; // 待打开章节的 URL（含 uuid），用于校验迟到的收图结果
  String? _prefetchTargetUrl;
  ChapterData? _prefetchedData;
  String? _prefetchedForUrl;

  // 阅读器
  ValueNotifier<ChapterData>? _readerNotifier;
  final ValueNotifier<String?> _readerLoading = ValueNotifier(null);
  bool _readerOpen = false;

  // 漫画详情页的批量下载入口（对应原生版 setFab）
  String _comicTitle = '';
  String? _comicStructureJson;
  bool _fabVisible = false;

  // 可拖动悬浮按钮（对应原生版 SetDraggable）；null = 用默认「右侧偏上」
  Offset? _fabOffset;
  bool _fabDragging = false;
  bool _suppressFabTap = false;

  // 状态栏运行时隐藏状态
  bool _statusBarHidden = false;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _loadFabOffset();
    AppSettings.darkMode.addListener(_onDarkModeChanged);
    AppSettings.hideStatusBar.addListener(_applyStatusBar);
    _statusBarHidden = AppSettings.hideStatusBar.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyStatusBar();
      _checkOffline();
    });
  }

  Future<void> _loadFabOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('fab_dx');
    final dy = prefs.getDouble('fab_dy');
    if (dx != null && dy != null && mounted) {
      setState(() => _fabOffset = Offset(dx, dy));
    }
  }

  Future<void> _saveFabOffset(Offset o) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fab_dx', o.dx);
    await prefs.setDouble('fab_dy', o.dy);
  }

  Future<void> _loadAssets() async {
    String strip(String s) =>
        s.startsWith('javascript:') ? s.substring('javascript:'.length) : s;
    _gmShim = await rootBundle.loadString('assets/js/gm_shim.js');
    _iJs = strip(await rootBundle.loadString('assets/js/i.js'));
    _hJs = strip(await rootBundle.loadString('assets/js/h.js'));
    if (mounted) setState(() => _assetsLoaded = true);
  }

  /// 无网络/全部源不可用时引导离线阅读
  Future<void> _checkOffline() async {
    var offline = UrlManager.allSourcesDown;
    if (!offline) {
      try {
        final results = await Connectivity().checkConnectivity();
        offline = results.every((r) => r == ConnectivityResult.none);
      } catch (_) {}
    }
    if (offline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('当前无可用网络，已为你打开本地下载'),
          duration: Duration(seconds: 3)));
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DownloadsPage()));
    }
  }

  // ---- 暗色模式 ----

  void _onDarkModeChanged() {
    final on = AppSettings.darkMode.value;
    _visibleController
        ?.evaluateJavascript(source: on ? darkModeJs : removeDarkModeJs);
    _hiddenController
        ?.evaluateJavascript(source: on ? darkModeJs : removeDarkModeJs);
    _syncSystemUi();
    // 刷新 Scaffold 顶/底安全区底色（与网页明暗一致）
    if (mounted) setState(() {});
  }

  // ---- 状态栏 ----

  void _applyStatusBar() {
    _statusBarHidden = AppSettings.hideStatusBar.value;
    _syncSystemUi();
    if (mounted) setState(() {});
  }

  void _toggleStatusBarRuntime() {
    _statusBarHidden = !_statusBarHidden;
    _syncSystemUi();
    if (mounted) setState(() {});
  }

  /// 顶/底安全区由页面 Padding 自行让出（顶=状态栏/刘海，底=Home 指示条）。
  void _syncSystemUi() {
    AppSystemUi.applyBrowser(statusBarHidden: _statusBarHidden);
  }

  /// 网页外露底色：浅色白、暗色黑（与暗色 CSS 反色后的观感一致）。
  Color get _chromeColor =>
      AppSettings.darkMode.value ? Colors.black : Colors.white;

  NavigationActionPolicy _allowNavigation(WebUri? url) {
    if (url == null) return NavigationActionPolicy.CANCEL;
    final s = url.toString();
    if (s == 'about:blank' ||
        UrlManager.allowedPrefixes.any((p) => s.startsWith(p))) {
      return NavigationActionPolicy.ALLOW;
    }
    return NavigationActionPolicy.CANCEL;
  }

  void _loadHiddenUrl(String url) {
    _hiddenController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  // ---- 可见 WebView 的 GM 桥（对应 JS.kt）----
  void _registerVisibleHandlers(InAppWebViewController c) {
    c.addJavaScriptHandler(
      handlerName: 'loadComic',
      callback: (args) {
        final url = args.isNotEmpty ? args[0] as String : '';
        final hidden = UrlManager.toHiddenUrl(url);
        if (hidden.isEmpty) return;
        if (url.contains('/comicContent/')) {
          // 章节页：收图并打开阅读器
          _pendingOpen = true;
          _pendingUrl = url;
          _prefetchTargetUrl = null;
          _prefetchedData = null;
          _prefetchedForUrl = null;
          _loadHiddenUrl(hidden);
          // 页面可能一直打不开、h.js 根本没机会弹加载框，也要有停滞守护兜底
          _armStallWatch();
        } else {
          // 详情页：抓章节结构（setFab）。若正在为用户收图，禁止顶掉隐藏 WebView
          if (_pendingOpen) return;
          _loadHiddenUrl(hidden);
        }
      },
    );
    c.addJavaScriptHandler(handlerName: 'hideFab', callback: (_) {
      if (_fabVisible && mounted) setState(() => _fabVisible = false);
    });
    c.addJavaScriptHandler(handlerName: 'enterProfile', callback: (_) {});
    c.addJavaScriptHandler(handlerName: 'openSettings', callback: (_) {
      if (mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
      }
    });
    c.addJavaScriptHandler(handlerName: 'toggleStatusBar', callback: (_) {
      _toggleStatusBarRuntime();
    });
  }

  // ---- 隐藏 WebView 的 GM 桥（对应 JSHidden.kt）----
  void _registerHiddenHandlers(InAppWebViewController c) {
    c.addJavaScriptHandler(
      handlerName: 'loadChapter',
      callback: (args) {
        if (args.isEmpty) return;
        final data = ChapterData.parse(args[0] as String);
        if (data == null || data.imgUrls.isEmpty) return;
        _onChapterDataArrived(data);
      },
    );
    c.addJavaScriptHandler(handlerName: 'setTitle', callback: (args) {
      if (args.isNotEmpty) _comicTitle = args[0] as String;
    });
    c.addJavaScriptHandler(handlerName: 'setFab', callback: (args) {
      if (args.isEmpty) return;
      _comicStructureJson = args[0] as String;
      if (mounted) setState(() => _fabVisible = true);
    });
    c.addJavaScriptHandler(
      handlerName: 'setLoadingDialog',
      callback: (args) {
        final show = args.isNotEmpty && args[0] == true;
        // 预取静默：不弹加载框
        if (!_pendingOpen && _prefetchTargetUrl != null) return;
        // h.js 在 loadChapter 前会先 setLoadingDialog(false)。若用户已改求另一章，
        // 旧章迟到的 false 会拆掉新章加载框并 cancel 停滞守护——此处忽略，
        // 成功关闭只由匹配的 loadChapter 路径负责。
        if (!show && _pendingOpen) return;
        _setLoading(show);
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'setLoadingDialogProgress',
      callback: (args) {
        if (args.length < 2) return;
        // 预取静默：也不刷新停滞计时，避免预取进度“续命”用户可见的等待
        if (!_pendingOpen && _prefetchTargetUrl != null) return;
        if (!_pendingOpen && !_loadingChapter && !_readerOpen) return;
        _lastProgressAt = DateTime.now();
        final text = '${args[0]}/${args[1]}';
        if (_readerOpen) {
          _readerLoading.value = '收集图片 $text';
        } else if (mounted) {
          setState(() => _loadingProgress = text);
        }
      },
    );
  }

  bool _uuidMatches(String? url, ChapterData data) {
    if (url == null || data.uuid.isEmpty) return true;
    return url.contains(data.uuid);
  }

  void _onChapterDataArrived(ChapterData data) {
    // 校验：预取/旧章结果可能在用户请求另一章之后才迟到，uuid 对不上就丢弃。
    if (_pendingOpen) {
      if (!_uuidMatches(_pendingUrl, data)) return;
      _pendingOpen = false;
      _pendingUrl = null;
      _prefetchedData = null;
      _prefetchedForUrl = null;
      _setLoading(false);
      _readerLoading.value = null;
      _openOrSwapReader(data);
      return;
    }
    if (_prefetchTargetUrl != null) {
      if (!_uuidMatches(_prefetchTargetUrl, data)) return;
      _prefetchedData = data;
      _prefetchedForUrl = _prefetchTargetUrl;
      _prefetchTargetUrl = null;
    }
  }

  void _openOrSwapReader(ChapterData data) {
    if (!mounted) return;
    if (_readerOpen && _readerNotifier != null) {
      _readerNotifier!.value = data;
      return;
    }
    final notifier = ValueNotifier<ChapterData>(data);
    _readerNotifier = notifier;
    _readerOpen = true;
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => ReaderPage(
        dataNotifier: notifier,
        loadingText: _readerLoading,
        onRequestChapter: _requestChapter,
        onPrefetch: _prefetchChapter,
      ),
    ))
        .then((_) {
      _readerOpen = false;
      _readerNotifier = null;
      _readerLoading.value = null;
      _pendingOpen = false;
      _pendingUrl = null;
      notifier.dispose();
      // 恢复浏览页的状态栏设置（阅读器是全隐藏）
      _applyStatusBar();
    });
  }

  void _requestChapter(String mobileUrl) {
    if (_prefetchedData != null && _prefetchedForUrl == mobileUrl) {
      final data = _prefetchedData!;
      _prefetchedData = null;
      _prefetchedForUrl = null;
      _openOrSwapReader(data);
      return;
    }
    final pc = UrlManager.toPcUrl(mobileUrl);
    if (pc.isEmpty) return;
    _pendingOpen = true;
    _pendingUrl = mobileUrl;
    _readerLoading.value = '正在收集图片…';
    if (_prefetchTargetUrl == mobileUrl) {
      _prefetchTargetUrl = null;
      _armStallWatch();
      return;
    }
    _prefetchTargetUrl = null;
    _loadHiddenUrl(pc);
    _armStallWatch();
  }

  void _prefetchChapter(String mobileUrl) {
    if (_pendingOpen) return;
    if (_prefetchTargetUrl == mobileUrl || _prefetchedForUrl == mobileUrl) return;
    final pc = UrlManager.toPcUrl(mobileUrl);
    if (pc.isEmpty) return;
    _prefetchTargetUrl = mobileUrl;
    _prefetchedData = null;
    _prefetchedForUrl = null;
    _loadHiddenUrl(pc);
  }

  void _setLoading(bool show) {
    if (!mounted) return;
    if (_readerOpen) {
      _readerLoading.value = show ? '正在收集图片…' : null;
    } else {
      setState(() {
        _loadingChapter = show;
        if (show) _loadingProgress = '';
      });
    }
    if (show) {
      _armStallWatch();
    } else {
      _stallTimer?.cancel();
    }
  }

  void _armStallWatch() {
    _lastProgressAt = DateTime.now();
    _stallTimer?.cancel();
    _stallTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (DateTime.now().difference(_lastProgressAt).inSeconds >= 45) {
        t.cancel();
        _pendingOpen = false;
        _pendingUrl = null;
        _readerLoading.value = null;
        if (mounted) {
          setState(() => _loadingChapter = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('收图停滞，请检查网络或到设置里换源后重试'),
              duration: Duration(seconds: 3)));
        }
      }
    });
  }

  Future<bool> _handleBack() async {
    if (_visibleController != null && await _visibleController!.canGoBack()) {
      await _visibleController!.goBack();
      return false;
    }
    return true;
  }

  void _openDownloadSelect() {
    final json = _comicStructureJson;
    if (json == null) return;
    List<ComicGroup> groups;
    try {
      groups = ComicGroup.parseList(json);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('章节列表解析失败'), duration: Duration(seconds: 2)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DownloadSelectPage(
        comicName: _comicTitle.isEmpty ? '未命名漫画' : _comicTitle,
        groups: groups,
      ),
    ));
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDarkModeChanged);
    AppSettings.hideStatusBar.removeListener(_applyStatusBar);
    _stallTimer?.cancel();
    _readerLoading.dispose();
    super.dispose();
  }

  InAppWebViewSettings get _hiddenSettings => InAppWebViewSettings(
        userAgent: pcUserAgent,
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
      );

  Future<void> _injectHidden(InAppWebViewController controller) async {
    await Future.delayed(const Duration(milliseconds: 500));
    await controller.evaluateJavascript(
        source: "window.__CM_SOURCE_PROFILE='${AppSettings.sourceProfile}';"
            "window.__CM_ACTIVE_URL='${UrlManager.activeUrl}';");
    await controller.evaluateJavascript(source: _gmShim);
    await controller.evaluateJavascript(source: _hJs);
  }

  Future<void> _injectVisible(InAppWebViewController controller) async {
    await Future.delayed(const Duration(milliseconds: 500));
    await controller.evaluateJavascript(source: _gmShim);
    await controller.evaluateJavascript(source: _iJs);
    await controller.evaluateJavascript(source: _dblTapJs);
  }

  @override
  Widget build(BuildContext context) {
    if (!_assetsLoaded) {
      return Scaffold(
        backgroundColor: _chromeColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _handleBack()) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // 关键：禁止 Flutter 随键盘压缩整页，否则 WKWebView 重排会导致
        // 登录框从屏幕上方「闪」到下方、输入时抖动。交给网页自己滚动。
        resizeToAvoidBottomInset: false,
        // 顶/底安全区底色跟 App 暗色开关（与站点反色后一致），勿跟系统主题
        backgroundColor: _chromeColor,
        // 去掉 viewInsets，避免键盘高度变化层层传给 WebView 触发二次重排
        body: MediaQuery.removeViewInsets(
          removeBottom: true,
          context: context,
          child: Padding(
            // 顶：状态栏/刘海（viewPadding，不受键盘影响）
            // 底：系统 Home 指示条高度（读不到时 iOS 回退 34pt）
            padding: EdgeInsets.only(
              top: _statusBarHidden
                  ? 0
                  : MediaQuery.viewPaddingOf(context).top,
              bottom: AppSystemUi.homeIndicatorHeight(context),
            ),
            child: Stack(
              children: [
              // 隐藏 WebView：真实控件，被上层可见 WebView 完全遮挡
              Positioned.fill(
                child: IgnorePointer(
                  child: InAppWebView(
                    initialSettings: _hiddenSettings,
                    onWebViewCreated: (controller) {
                      _hiddenController = controller;
                      _registerHiddenHandlers(controller);
                    },
                    shouldOverrideUrlLoading: (controller, action) async =>
                        _allowNavigation(action.request.url),
                    onProgressChanged: (controller, progress) {
                      if (progress > 2 && AppSettings.darkMode.value) {
                        controller.evaluateJavascript(source: darkModeJs);
                      }
                    },
                    onLoadStop: (controller, url) => _injectHidden(controller),
                  ),
                ),
              ),
              // 可见 WebView
              Positioned.fill(
                child: InAppWebView(
                  initialUrlRequest:
                      URLRequest(url: WebUri(UrlManager.activeUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: true,
                    // 减少 iOS 键盘弹出时的额外视口跳动
                    supportZoom: false,
                    allowsBackForwardNavigationGestures: false,
                    // 禁止 WKWebView 随安全区/键盘自动改 contentInset（抖动主因之一）
                    contentInsetAdjustmentBehavior:
                        ScrollViewContentInsetAdjustmentBehavior.NEVER,
                    disableInputAccessoryView: true,
                  ),
                  onWebViewCreated: (controller) {
                    _visibleController = controller;
                    _registerVisibleHandlers(controller);
                  },
                  shouldOverrideUrlLoading: (controller, action) async =>
                      _allowNavigation(action.request.url),
                  onProgressChanged: (controller, progress) {
                    if (mounted) setState(() => _webProgress = progress);
                    // 尽早注入暗色 CSS，避免加载过程白屏闪烁（对应原生版 WebChromeClient）
                    if (progress > 2 && AppSettings.darkMode.value) {
                      controller.evaluateJavascript(source: darkModeJs);
                    }
                  },
                  onLoadStop: (controller, url) => _injectVisible(controller),
                  // 网站的 JS 弹窗全部自动确认（对应原生版 WebChromeClient）
                  onJsAlert: (controller, request) async =>
                      JsAlertResponse(handledByClient: true),
                  onJsConfirm: (controller, request) async => JsConfirmResponse(
                      handledByClient: true,
                      action: JsConfirmResponseAction.CONFIRM),
                  onJsPrompt: (controller, request) async => JsPromptResponse(
                      handledByClient: true,
                      action: JsPromptResponseAction.CONFIRM),
                ),
              ),
              // 顶部网页加载进度条（对应原生版 pw ProgressBar）
              if (_webProgress < 100)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                      value: _webProgress / 100, minHeight: 2),
                ),
              if (_loadingChapter)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(_loadingProgress.isEmpty
                                  ? '正在收集图片…'
                                  : '收集图片 $_loadingProgress'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // 可拖动悬浮钮：默认右侧偏上，不挡底栏「个人」；长按拖动，松手记住位置
              _buildDraggableFab(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableFab() {
    const fabSize = 40.0;
    const gap = 10.0;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackH = _fabVisible ? fabSize * 2 + gap : fabSize;
          final maxX = (constraints.maxWidth - fabSize).clamp(0.0, double.infinity);
          final maxY = (constraints.maxHeight - stackH).clamp(0.0, double.infinity);
          // 默认：右侧、约 28% 高度处（偏上，避开底栏与常见网页按钮）
          final def = Offset(maxX - 8, constraints.maxHeight * 0.28);
          final raw = _fabOffset ?? def;
          final x = raw.dx.clamp(0.0, maxX);
          final y = raw.dy.clamp(0.0, maxY);
          return Stack(
            children: [
              Positioned(
                left: x,
                top: y,
                child: GestureDetector(
                  onPanStart: (_) {
                    _fabDragging = false;
                  },
                  onPanUpdate: (d) {
                    final cur = _fabOffset ?? Offset(x, y);
                    final next = Offset(
                      (cur.dx + d.delta.dx).clamp(0.0, maxX),
                      (cur.dy + d.delta.dy).clamp(0.0, maxY),
                    );
                    if ((next - cur).distanceSquared > 9) {
                      _fabDragging = true;
                    }
                    setState(() => _fabOffset = next);
                  },
                  onPanEnd: (_) {
                    if (_fabDragging) {
                      _suppressFabTap = true;
                      Future.delayed(const Duration(milliseconds: 80), () {
                        _suppressFabTap = false;
                        _fabDragging = false;
                      });
                      if (_fabOffset != null) _saveFabOffset(_fabOffset!);
                    } else {
                      _fabDragging = false;
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_fabVisible) ...[
                        FloatingActionButton.small(
                          heroTag: 'fab_dl',
                          tooltip: '下载本漫画',
                          onPressed: () {
                            if (_fabDragging || _suppressFabTap) return;
                            _openDownloadSelect();
                          },
                          child: const Icon(Icons.download),
                        ),
                        const SizedBox(height: gap),
                      ],
                      Opacity(
                        opacity: 0.85,
                        child: FloatingActionButton.small(
                          heroTag: 'fab_list',
                          tooltip: '我的下载（可拖动）',
                          onPressed: () {
                            if (_fabDragging || _suppressFabTap) return;
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const DownloadsPage()));
                          },
                          child: const Icon(Icons.folder_open),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
