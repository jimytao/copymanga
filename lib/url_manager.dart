import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 多域名测速与缓存，对应原生版 UrlManager.kt。
/// 与原生版一致：手动模式（manual_url）优先于自动测速结果且不被覆盖。
/// 测速时校验页面内容确实是拷贝漫画站点，防止过期域名停靠页赢得测速。
class UrlManager {
  static const candidates = [
    'https://www.copy3000.com',
    'https://www.2026copy.com',
    'https://www.mangacopy.com',
    'https://www.copymanga.site',
  ];

  static List<String> get allowedPrefixes => [
        ...candidates,
        ...candidates.map((u) => u.replaceFirst('://www.', '://')),
      ];

  static String activeUrl = candidates[0];
  static bool manualMode = false;

  /// 启动时若所有源都不可用则为 true（引导离线阅读）
  static bool allSourcesDown = false;

  static String get comicDetailUrl => '$activeUrl/comic';

  /// 是否已有可用的缓存/手动源（有则启动不必等网络）
  static bool hasCachedUrl = false;

  /// 手机版章节 URL 转 PC 版（供隐藏 WebView 收图）
  static String toPcUrl(String mobileUrl) {
    if (!mobileUrl.contains('/comicContent/')) return '';
    final rest = mobileUrl.split('comicContent/')[1];
    final slug = rest.split('/')[0];
    final uuid = mobileUrl.substring(mobileUrl.lastIndexOf('/') + 1);
    return '$comicDetailUrl/$slug/chapter/$uuid';
  }

  /// 详情页/章节页 URL 统一转 PC 版
  static String toHiddenUrl(String url) {
    if (url.contains('/details/comic/')) {
      final after =
          url.substring(url.indexOf('/details/comic/') + '/details/comic'.length);
      return '$comicDetailUrl$after';
    }
    if (url.contains('/comicContent/')) return toPcUrl(url);
    return '';
  }

  /// 任意源的章节 URL 换到当前源（下载列表里存的 URL 可能来自旧源）
  static String rehost(String url) {
    for (final p in allowedPrefixes) {
      if (url.startsWith(p)) {
        return activeUrl + url.substring(p.length);
      }
    }
    return url;
  }

  /// 校验域名确实是拷贝漫画站点并测量耗时；无效返回 null
  static Future<int?> _validate(String url) async {
    final sw = Stopwatch()..start();
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final body = resp.body;
      final isCopyManga = body.contains('拷貝漫畫') ||
          body.contains('拷贝漫画') ||
          body.contains('copymanga');
      return isCopyManga ? sw.elapsedMilliseconds : null;
    } catch (_) {
      return null;
    }
  }

  /// 仅读本地缓存，不访问网络。对应原生版 UrlManager.init + hasCachedUrl。
  /// 返回是否已有缓存/手动源（有则主页可立刻加载，测速放到后台）。
  static Future<bool> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final manual = prefs.getString('manual_url');
    if (manual != null && candidates.contains(manual)) {
      manualMode = true;
      activeUrl = manual;
      hasCachedUrl = true;
      return true;
    }
    final cached = prefs.getString('active_url');
    if (cached != null && candidates.contains(cached)) {
      activeUrl = cached;
      hasCachedUrl = true;
      return true;
    }
    hasCachedUrl = false;
    return false;
  }

  /// 手动指定源站
  static Future<void> setManualUrl(String url) async {
    manualMode = true;
    activeUrl = url;
    hasCachedUrl = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manual_url', url);
  }

  /// 恢复自动选源并立即测速
  static Future<String> clearManualUrl() async {
    manualMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('manual_url');
    return probe();
  }

  /// 并发校验全部候选，选内容正确且最快的（手动模式下不改 activeUrl）
  static Future<String> probe() async {
    final results = await Future.wait(
      candidates.map((url) async => MapEntry(url, await _validate(url))),
    );
    final valid = results.where((e) => e.value != null).toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));
    allSourcesDown = valid.isEmpty;
    if (valid.isNotEmpty && !manualMode) {
      activeUrl = valid.first.key;
      hasCachedUrl = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_url', activeUrl);
    }
    return activeUrl;
  }
}
