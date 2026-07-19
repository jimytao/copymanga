import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置，对应原生版 PropertiesTools(settings.properties) + app_settings。
class AppSettings {
  static late SharedPreferences _prefs;

  /// 'h' 横向翻页 / 'v' 纵向翻页 / 'w' 条漫连续滚动
  static String readMode = 'h';

  /// 右开本（右滑=下一页，日漫习惯）
  static bool r2l = true;

  /// 阅读器右下角常驻页码
  static bool showPageNum = true;

  /// h.js 收图滚动速度：conservative / normal / fast / turbo
  static String sourceProfile = 'fast';

  /// 音量键翻页
  static bool volTurn = false;

  /// 夜间模式（含 WebView CSS 反色）；用 notifier 让主题和 WebView 即时响应
  static final ValueNotifier<bool> darkMode = ValueNotifier(false);

  /// 隐藏浏览页状态栏
  static final ValueNotifier<bool> hideStatusBar = ValueNotifier(false);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    readMode = _prefs.getString('readMode') ?? 'h';
    r2l = _prefs.getBool('r2l') ?? true;
    showPageNum = _prefs.getBool('showPageNum') ?? true;
    sourceProfile = _prefs.getString('sourceProfile') ?? 'fast';
    volTurn = _prefs.getBool('volTurn') ?? false;
    darkMode.value = _prefs.getBool('darkMode') ?? false;
    hideStatusBar.value = _prefs.getBool('hideStatusBar') ?? false;
  }

  static Future<void> setReadMode(String v) async {
    readMode = v;
    await _prefs.setString('readMode', v);
  }

  static Future<void> setR2l(bool v) async {
    r2l = v;
    await _prefs.setBool('r2l', v);
  }

  static Future<void> setShowPageNum(bool v) async {
    showPageNum = v;
    await _prefs.setBool('showPageNum', v);
  }

  static Future<void> setSourceProfile(String v) async {
    sourceProfile = v;
    await _prefs.setString('sourceProfile', v);
  }

  static Future<void> setVolTurn(bool v) async {
    volTurn = v;
    await _prefs.setBool('volTurn', v);
  }

  static Future<void> setDarkMode(bool v) async {
    darkMode.value = v;
    await _prefs.setBool('darkMode', v);
  }

  static Future<void> setHideStatusBar(bool v) async {
    hideStatusBar.value = v;
    await _prefs.setBool('hideStatusBar', v);
  }
}

/// WebView 暗色 CSS 反色注入（与原生版 WebChromeClient.darkModeJs 相同）
const darkModeJs =
    "(function(){var e=document.getElementById('_dk');if(!e){e=document.createElement('style');e.id='_dk';(document.head||document.documentElement).appendChild(e);}e.textContent='html{filter:invert(1) hue-rotate(180deg)!important;background-color:#fff!important}img,video{filter:invert(1) hue-rotate(180deg)!important}'})();";

/// 移除暗色 CSS
const removeDarkModeJs =
    "(function(){var e=document.getElementById('_dk');if(e)e.remove();})();";
