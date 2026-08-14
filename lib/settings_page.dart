import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import 'downloads_page.dart';
import 'image_cache_store.dart';
import 'settings.dart';
import 'url_manager.dart';

/// App 扩展设置：外观、阅读、收图速度、源站、缓存。对应原生版 SettingsActivity。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _probing = false;
  String _probeResult = '';
  String _cacheText = '计算中…';

  @override
  void initState() {
    super.initState();
    _updateCacheText();
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }

  String _formatBytes(int bytes) => bytes > 1024 * 1024 * 1024
      ? '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB'
      : bytes > 1024 * 1024
      ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';

  Future<void> _updateCacheText() async {
    try {
      final tmp = await getTemporaryDirectory();
      final bytes = await _dirSize(tmp);
      if (mounted) {
        setState(() => _cacheText = '当前缓存约 ${_formatBytes(bytes)}，点击清理');
      }
    } catch (_) {
      if (mounted) setState(() => _cacheText = '缓存大小读取失败，点击清理');
    }
  }

  Future<void> _pickCacheLimit() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('图片缓存上限'),
        children: [
          RadioGroup<int>(
            groupValue: AppSettings.imageCacheLimitMb,
            onChanged: (v) => Navigator.pop(c, v),
            child: Column(
              children: [
                for (final mb in AppSettings.imageCacheLimitOptionsMb)
                  RadioListTile<int>(
                    value: mb,
                    title: Text(AppSettings.formatCacheLimit(mb)),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              '达到上限后，自动删除最久没看过的图片，直到降回上限的 80%。'
              '已下载到本地的漫画不受影响。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await AppSettings.setImageCacheLimitMb(picked);
    if (!mounted) return;
    setState(() {});
    await AppImageCache.trim();
    if (mounted) _updateCacheText();
  }

  Future<void> _clearCache() async {
    try {
      await InAppWebViewController.clearAllCache();
    } catch (_) {}
    await AppImageCache.clear();
    try {
      final tmp = await getTemporaryDirectory();
      if (await tmp.exists()) {
        await for (final e in tmp.list()) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _cacheText = '已清理完成（0 B）');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清理'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _reprobe() async {
    setState(() {
      _probing = true;
      _probeResult = '';
    });
    final best = await UrlManager.probe();
    if (mounted) {
      setState(() {
        _probing = false;
        _probeResult = UrlManager.lastProbeNote.isNotEmpty
            ? UrlManager.lastProbeNote
            : '当前使用：$best';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App 扩展设置')),
      body: ListView(
        children: [
          const _SectionHeader('外观'),
          SwitchListTile(
            title: const Text('夜间模式'),
            subtitle: const Text('App 主题与网页同时反色'),
            value: AppSettings.darkMode.value,
            onChanged: (v) async {
              await AppSettings.setDarkMode(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('隐藏状态栏'),
            subtitle: const Text('浏览页也可双击网页快捷切换'),
            value: AppSettings.hideStatusBar.value,
            onChanged: (v) async {
              await AppSettings.setHideStatusBar(v);
              setState(() {});
            },
          ),
          const Divider(),
          const _SectionHeader('阅读'),
          ListTile(
            title: const Text('默认阅读模式'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'h', label: Text('横向')),
                ButtonSegment(value: 'v', label: Text('纵向')),
                ButtonSegment(value: 'w', label: Text('条漫')),
              ],
              selected: {AppSettings.readMode},
              onSelectionChanged: (s) async {
                await AppSettings.setReadMode(s.first);
                setState(() {});
              },
            ),
          ),
          SwitchListTile(
            title: const Text('右开本（右滑下一页）'),
            subtitle: const Text('仅横向模式生效'),
            value: AppSettings.r2l,
            onChanged: (v) async {
              await AppSettings.setR2l(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('显示页码角标'),
            value: AppSettings.showPageNum,
            onChanged: (v) async {
              await AppSettings.setShowPageNum(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('音量键翻页'),
            value: AppSettings.volTurn,
            onChanged: (v) async {
              await AppSettings.setVolTurn(v);
              setState(() {});
            },
          ),
          const Divider(),
          const _SectionHeader('收图速度'),
          ListTile(
            title: const Text('隐藏页滚动速度'),
            subtitle: const Text('网络差时选保守可减少漏图'),
            trailing: DropdownButton<String>(
              value: AppSettings.sourceProfile,
              items: const [
                DropdownMenuItem(value: 'conservative', child: Text('保守')),
                DropdownMenuItem(value: 'normal', child: Text('普通')),
                DropdownMenuItem(value: 'fast', child: Text('快速')),
                DropdownMenuItem(value: 'turbo', child: Text('极速')),
              ],
              onChanged: (v) async {
                if (v != null) {
                  await AppSettings.setSourceProfile(v);
                  setState(() {});
                }
              },
            ),
          ),
          const Divider(),
          const _SectionHeader('源站'),
          ListTile(
            dense: true,
            title: Text(
              UrlManager.manualMode
                  ? '当前为手动模式：自动测速不会替你换源'
                  : '当前为自动模式：沿用已选源站，仅失效或明显过慢时切换',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          RadioGroup<String>(
            groupValue: UrlManager.manualMode ? UrlManager.activeUrl : '',
            onChanged: (v) async {
              if (v != null && v.isNotEmpty) {
                await UrlManager.setManualUrl(v);
                setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已手动切换源站，重启 App 生效'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: Column(
              children: [
                for (final url in UrlManager.candidates)
                  RadioListTile<String>(
                    title: Text(url.replaceFirst('https://', '')),
                    subtitle: url == UrlManager.activeUrl
                        ? const Text('当前使用')
                        : null,
                    value: url,
                  ),
              ],
            ),
          ),
          ListTile(
            title: const Text('恢复自动选源'),
            enabled: UrlManager.manualMode,
            leading: const Icon(Icons.autorenew),
            onTap: () async {
              final best = await UrlManager.clearManualUrl();
              setState(() {});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已恢复自动模式，当前使用 $best'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          ListTile(
            title: const Text('重新测速'),
            subtitle: _probeResult.isEmpty ? null : Text(_probeResult),
            leading: _probing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed),
            onTap: _probing ? null : _reprobe,
          ),
          const Divider(),
          const _SectionHeader('存储'),
          ListTile(
            title: const Text('我的下载'),
            subtitle: const Text('管理、阅读或删除已下载的漫画'),
            leading: const Icon(Icons.folder_open),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DownloadsPage())),
          ),
          ListTile(
            title: const Text('缓存上限'),
            subtitle: Text(
              '${AppSettings.formatCacheLimit(AppSettings.imageCacheLimitMb)}'
              '：超过后自动删除最久未看的图片',
            ),
            leading: const Icon(Icons.data_usage),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickCacheLimit,
          ),
          ListTile(
            title: const Text('清理缓存'),
            subtitle: Text(_cacheText),
            leading: const Icon(Icons.cleaning_services),
            onTap: _clearCache,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
