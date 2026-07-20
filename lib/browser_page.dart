import 'dart:async';
import 'dart:collection';

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
/// 阅读器嵌在本页 Stack（非另开 opaque 路由）；收图时隐藏 WebView 以 1×1 置顶，
/// 保证 requestAnimationFrame 不被节流。阅读器内切章不改动可见 H5（避免盖住时
/// clickClass / 深链把表页打回首页）；退出时 resume 表页定时器以恢复二次进章。
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

  /// 隐藏 WebView 注入代数：快速连切时丢弃过期的 500ms 延迟注入
  int _hiddenInjectGen = 0;

  /// 阅读器打开且正在收图/预取时，把隐藏 WebView 提到 Stack 顶（1×1）避免 rAF 被节流
  bool _hiddenOnTop = false;
  final GlobalKey _hiddenWebViewKey = GlobalKey();
  bool _hiddenHandlersRegistered = false;
  bool _visibleHandlersRegistered = false;

  // 阅读器（嵌在本页 Stack，不用 opaque 路由盖住 WebView）
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前无可用网络，已为你打开本地下载'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DownloadsPage()));
    }
  }

  // ---- 暗色模式 ----

  /// 在 document 创建最早阶段注入，避免 iOS 首帧白闪后再等 progress>2。
  late final UserScript _darkModeUserScript = UserScript(
    source: darkModeJs,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: false,
  );

  UnmodifiableListView<UserScript> get _darkModeInitialScripts =>
      AppSettings.darkMode.value
      ? UnmodifiableListView<UserScript>([_darkModeUserScript])
      : UnmodifiableListView<UserScript>(const []);

  Future<void> _applyDarkModeToController(
    InAppWebViewController? c,
    bool on,
  ) async {
    if (c == null) return;
    if (on) {
      await c.addUserScript(userScript: _darkModeUserScript);
      await c.evaluateJavascript(source: darkModeJs);
    } else {
      await c.removeUserScript(userScript: _darkModeUserScript);
      await c.evaluateJavascript(source: removeDarkModeJs);
    }
    await c.setSettings(
      settings: InAppWebViewSettings(
        underPageBackgroundColor: on ? Colors.black : Colors.white,
      ),
    );
  }

  void _onDarkModeChanged() {
    final on = AppSettings.darkMode.value;
    unawaited(_applyDarkModeToController(_visibleController, on));
    unawaited(_applyDarkModeToController(_hiddenController, on));
    _syncSystemUi();
    // 刷新 Scaffold 顶/底安全区底色（与网页明暗一致）
    if (mounted) setState(() {});
  }

  /// 每次导航开始立刻再打一针（UserScript 覆盖新建 document；此为双保险）
  void _injectDarkModeIfNeeded(InAppWebViewController controller) {
    if (AppSettings.darkMode.value) {
      controller.evaluateJavascript(source: darkModeJs);
    }
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

  Future<void> _loadHiddenUrl(String url) async {
    final c = _hiddenController;
    if (c == null) return;
    _hiddenInjectGen++;
    try {
      await c.stopLoading();
      await c.resumeTimers();
    } catch (_) {}
    await c.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  /// iOS 上阅读器盖住表页后 WKWebView 会节流 setInterval；安卓因全局 resumeTimers
  /// 常被「顺便」救活。退出时恢复表页定时器，并把 preUrl 标成当前地址：
  /// 切勿 reset 成空串——表页若仍停在 /comicContent/，空 preUrl 会让 i.js 再次
  /// loadComic，阅读器会自动弹回来。
  Future<void> _reviveVisibleWebView() async {
    final c = _visibleController;
    if (c == null) return;
    try {
      await c.resumeTimers();
    } catch (_) {}
    try {
      await c.evaluateJavascript(
        source: '''
try {
  if (typeof invoke !== "undefined") {
    invoke.preUrl = location.href;
  }
} catch (e) {}
''',
      );
    } catch (_) {}
  }

  void _setHiddenOnTop(bool onTop) {
    if (_hiddenOnTop == onTop) return;
    if (mounted) {
      setState(() => _hiddenOnTop = onTop);
    } else {
      _hiddenOnTop = onTop;
    }
    if (onTop) {
      unawaited(_hiddenController?.resumeTimers() ?? Future.value());
    }
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
          // 阅读器内切章由 _requestChapter 驱动，不接受表页重复触发
          if (_readerOpen || _pendingOpen) return;
          // 章节页：收图并打开阅读器
          _pendingOpen = true;
          _pendingUrl = url;
          _prefetchTargetUrl = null;
          _prefetchedData = null;
          _prefetchedForUrl = null;
          unawaited(_loadHiddenUrl(hidden));
          // 页面可能一直打不开、h.js 根本没机会弹加载框，也要有停滞守护兜底
          _armStallWatch();
        } else {
          // 详情页：抓章节结构（setFab）。若正在为用户收图，禁止顶掉隐藏 WebView
          if (_pendingOpen || _readerOpen) return;
          unawaited(_loadHiddenUrl(hidden));
        }
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'hideFab',
      callback: (_) {
        if (_fabVisible && mounted) setState(() => _fabVisible = false);
      },
    );
    c.addJavaScriptHandler(handlerName: 'enterProfile', callback: (_) {});
    c.addJavaScriptHandler(
      handlerName: 'openSettings',
      callback: (_) {
        if (mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
        }
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'toggleStatusBar',
      callback: (_) {
        _toggleStatusBarRuntime();
      },
    );
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
    c.addJavaScriptHandler(
      handlerName: 'setTitle',
      callback: (args) {
        if (args.isNotEmpty) _comicTitle = args[0] as String;
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'setFab',
      callback: (args) {
        if (args.isEmpty) return;
        _comicStructureJson = args[0] as String;
        if (mounted) setState(() => _fabVisible = true);
      },
    );
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
      _prefetchTargetUrl = null;
      _setHiddenOnTop(false);
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
      if (!_pendingOpen) _setHiddenOnTop(false);
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
    setState(() => _readerOpen = true);
  }

  void _closeReader() {
    if (!_readerOpen) return;
    final n = _readerNotifier;
    _readerNotifier = null;
    _readerLoading.value = null;
    _pendingOpen = false;
    _pendingUrl = null;
    _prefetchTargetUrl = null;
    _prefetchedData = null;
    _prefetchedForUrl = null;
    _stallTimer?.cancel();
    _setHiddenOnTop(false);
    setState(() {
      _readerOpen = false;
      _loadingChapter = false;
    });
    // 等 Reader 从树移除后再 dispose，并唤醒被盖住期间节流的表页定时器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      n?.dispose();
      unawaited(_reviveVisibleWebView());
    });
    _applyStatusBar();
  }

  /// 阅读器打开时先把隐藏 WebView 置顶再 load，避免在旧层级上启动收图。
  void _loadHiddenForReader(
    String pcUrl, {
    required bool Function() stillValid,
  }) {
    void load() {
      if (!mounted || !stillValid()) return;
      unawaited(_loadHiddenUrl(pcUrl));
    }

    if (_readerOpen && !_hiddenOnTop) {
      _setHiddenOnTop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    } else {
      if (_readerOpen) _setHiddenOnTop(true);
      load();
    }
  }

  void _requestChapter(String mobileUrl, {bool? goNext}) {
    // 故意不在此处同步表 H5：阅读器盖住时 clickClass/深链都会把可见页打乱（安卓尤甚，关阅读器像回首页）。
    // goNext 仍由 ReaderPage 传入，供日后更安全的退出时同步使用。
    if (_prefetchedData != null && _prefetchedForUrl == mobileUrl) {
      final data = _prefetchedData!;
      _prefetchedData = null;
      _prefetchedForUrl = null;
      _prefetchTargetUrl = null;
      _setHiddenOnTop(false);
      _openOrSwapReader(data);
      return;
    }
    final pc = UrlManager.toPcUrl(mobileUrl);
    if (pc.isEmpty) return;
    _pendingOpen = true;
    _pendingUrl = mobileUrl;
    _readerLoading.value = '正在收集图片…';
    // 不再挂接可能已节流/僵死的预取：用户显式切章时强制重启隐藏 WebView
    _prefetchTargetUrl = null;
    _armStallWatch();
    _loadHiddenForReader(
      pc,
      stillValid: () => _pendingOpen && _pendingUrl == mobileUrl,
    );
  }

  void _prefetchChapter(String mobileUrl) {
    if (_pendingOpen) return;
    if (_prefetchTargetUrl == mobileUrl || _prefetchedForUrl == mobileUrl) {
      return;
    }
    final pc = UrlManager.toPcUrl(mobileUrl);
    if (pc.isEmpty) return;
    _prefetchTargetUrl = mobileUrl;
    _prefetchedData = null;
    _prefetchedForUrl = null;
    _loadHiddenForReader(
      pc,
      stillValid: () => !_pendingOpen && _prefetchTargetUrl == mobileUrl,
    );
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
        _prefetchTargetUrl = null;
        _setHiddenOnTop(false);
        _readerLoading.value = null;
        if (mounted) {
          setState(() => _loadingChapter = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('收图停滞，请检查网络或到设置里换源后重试'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  Future<bool> _handleBack() async {
    if (_readerOpen) {
      _closeReader();
      return false;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('章节列表解析失败'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DownloadSelectPage(
          comicName: _comicTitle.isEmpty ? '未命名漫画' : _comicTitle,
          groups: groups,
        ),
      ),
    );
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDarkModeChanged);
    AppSettings.hideStatusBar.removeListener(_applyStatusBar);
    _stallTimer?.cancel();
    _readerLoading.dispose();
    _readerNotifier?.dispose();
    super.dispose();
  }

  InAppWebViewSettings get _hiddenSettings => InAppWebViewSettings(
    userAgent: pcUserAgent,
    javaScriptEnabled: true,
    useShouldOverrideUrlLoading: true,
    useWideViewPort: true,
    loadWithOverviewMode: true,
    transparentBackground: true,
    underPageBackgroundColor: AppSettings.darkMode.value
        ? Colors.black
        : Colors.white,
  );

  InAppWebViewSettings get _visibleSettings => InAppWebViewSettings(
    javaScriptEnabled: true,
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: true,
    supportZoom: false,
    allowsBackForwardNavigationGestures: false,
    contentInsetAdjustmentBehavior:
        ScrollViewContentInsetAdjustmentBehavior.NEVER,
    disableInputAccessoryView: true,
    // 透明底 + 跟壳同色，减轻 iOS WKWebView 启动/切页白闪
    transparentBackground: true,
    underPageBackgroundColor: AppSettings.darkMode.value
        ? Colors.black
        : Colors.white,
  );

  Future<void> _injectHidden(InAppWebViewController controller) async {
    final gen = _hiddenInjectGen;
    await Future.delayed(const Duration(milliseconds: 500));
    if (gen != _hiddenInjectGen) return;
    await controller.evaluateJavascript(
      source:
          "window.__CM_SOURCE_PROFILE='${AppSettings.sourceProfile}';"
          "window.__CM_ACTIVE_URL='${UrlManager.activeUrl}';",
    );
    if (gen != _hiddenInjectGen) return;
    await controller.evaluateJavascript(source: _gmShim);
    if (gen != _hiddenInjectGen) return;
    await controller.evaluateJavascript(source: _hJs);
  }

  Future<void> _injectVisible(InAppWebViewController controller) async {
    await Future.delayed(const Duration(milliseconds: 500));
    await controller.evaluateJavascript(source: _gmShim);
    await controller.evaluateJavascript(source: _iJs);
    await controller.evaluateJavascript(source: _dblTapJs);
  }

  /// GlobalKey 保证在底层全屏 ↔ 顶层 1×1 之间切换时复用同一 WebView 实例
  Widget _buildHiddenWebView() {
    return InAppWebView(
      key: _hiddenWebViewKey,
      initialSettings: _hiddenSettings,
      initialUserScripts: _darkModeInitialScripts,
      onWebViewCreated: (controller) {
        _hiddenController = controller;
        if (!_hiddenHandlersRegistered) {
          _hiddenHandlersRegistered = true;
          _registerHiddenHandlers(controller);
        }
      },
      shouldOverrideUrlLoading: (controller, action) async =>
          _allowNavigation(action.request.url),
      onLoadStart: (controller, url) => _injectDarkModeIfNeeded(controller),
      onProgressChanged: (controller, progress) {
        if (progress > 0 && progress <= 10) {
          _injectDarkModeIfNeeded(controller);
        }
      },
      onLoadStop: (controller, url) => _injectHidden(controller),
    );
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
        // 外层 Stack：浏览区（含安全区 padding）+ 全屏阅读器 + 收图时顶置的 1×1 隐藏 WebView
        body: Stack(
          children: [
            MediaQuery.removeViewInsets(
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
                    if (!_hiddenOnTop)
                      Positioned.fill(
                        child: IgnorePointer(child: _buildHiddenWebView()),
                      ),
                    Positioned.fill(
                      child: InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(UrlManager.activeUrl),
                        ),
                        initialSettings: _visibleSettings,
                        initialUserScripts: _darkModeInitialScripts,
                        onWebViewCreated: (controller) {
                          _visibleController = controller;
                          if (!_visibleHandlersRegistered) {
                            _visibleHandlersRegistered = true;
                            _registerVisibleHandlers(controller);
                          }
                        },
                        shouldOverrideUrlLoading: (controller, action) async =>
                            _allowNavigation(action.request.url),
                        onLoadStart: (controller, url) =>
                            _injectDarkModeIfNeeded(controller),
                        onProgressChanged: (controller, progress) {
                          if (mounted) setState(() => _webProgress = progress);
                          if (progress > 0 && progress <= 10) {
                            _injectDarkModeIfNeeded(controller);
                          }
                        },
                        onLoadStop: (controller, url) =>
                            _injectVisible(controller),
                        onJsAlert: (controller, request) async =>
                            JsAlertResponse(handledByClient: true),
                        onJsConfirm: (controller, request) async =>
                            JsConfirmResponse(
                              handledByClient: true,
                              action: JsConfirmResponseAction.CONFIRM,
                            ),
                        onJsPrompt: (controller, request) async =>
                            JsPromptResponse(
                              handledByClient: true,
                              action: JsPromptResponseAction.CONFIRM,
                            ),
                      ),
                    ),
                    if (_webProgress < 100 && !_readerOpen)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: _webProgress / 100,
                          minHeight: 2,
                        ),
                      ),
                    if (_loadingChapter && !_readerOpen)
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
                                    Text(
                                      _loadingProgress.isEmpty
                                          ? '正在收集图片…'
                                          : '收集图片 $_loadingProgress',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_readerOpen) _buildDraggableFab(),
                  ],
                ),
              ),
            ),
            if (_readerOpen && _readerNotifier != null)
              Positioned.fill(
                child: ReaderPage(
                  dataNotifier: _readerNotifier!,
                  loadingText: _readerLoading,
                  onRequestChapter: _requestChapter,
                  onPrefetch: _prefetchChapter,
                  onClose: _closeReader,
                ),
              ),
            // 必须在阅读器之上，否则仍会被盖住导致 rAF 节流
            if (_hiddenOnTop)
              Positioned(
                left: 0,
                top: 0,
                width: 3,
                height: 3,
                child: IgnorePointer(child: _buildHiddenWebView()),
              ),
          ],
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
          final maxX = (constraints.maxWidth - fabSize).clamp(
            0.0,
            double.infinity,
          );
          final maxY = (constraints.maxHeight - stackH).clamp(
            0.0,
            double.infinity,
          );
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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DownloadsPage(),
                              ),
                            );
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
