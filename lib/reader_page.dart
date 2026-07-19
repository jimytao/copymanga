import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chapter_data.dart';
import 'downloader.dart';
import 'retry_image.dart';
import 'settings.dart';
import 'system_ui.dart';
import 'volume_keys.dart';

/// 全屏漫画阅读器：横/纵/条漫三模式、原地切章、断点续读、80% 预取、
/// 翻页到头再翻切章、音量键翻页、页码跳转、时间/网络信息栏。
/// 对应原生版 ViewMangaActivity。
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.dataNotifier,
    required this.loadingText,
    this.onRequestChapter,
    this.onPrefetch,
    this.onClose,
  });

  final ValueNotifier<ChapterData> dataNotifier;
  final ValueNotifier<String?> loadingText;
  final void Function(String mobileUrl)? onRequestChapter;
  final void Function(String mobileUrl)? onPrefetch;

  /// 嵌在 BrowserPage Stack 时由外层关闭；走 Navigator.push 时可空（系统返回）
  final VoidCallback? onClose;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late ChapterData _data;

  // 全生命周期单例：切章/切模式复用同一个控制器。
  // 若每章新建并 dispose 旧的，旧控制器在 PageView 下一帧解绑前仍被引用，会触发
  // "used after being disposed" 崩溃。
  final PageController _pageController = PageController();
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();

  int _page = 1; // 1-based
  bool _barsVisible = false;
  String _readMode = AppSettings.readMode;
  bool _r2l = AppSettings.r2l;
  bool _prefetchRequested = false;
  bool _downloading = false;
  String _downloadProgress = '';

  // 翻页到头再翻切章（对应原生版 isEndL/isEndR + doubleTapToast）
  bool _endHintNext = false;
  bool _endHintPrev = false;
  DateTime _lastOverscrollAt = DateTime.fromMillisecondsSinceEpoch(0);

  // 信息栏时钟
  Timer? _clockTimer;
  String _clockText = '';

  // 切章代数：丢弃过期的断点恢复/跳页回调，防止快速连切时旧章恢复落到新章上
  int _chapterGen = 0;

  int get _count => _data.imgUrls.length;
  bool get _isWebtoon => _readMode == 'w';

  @override
  void initState() {
    super.initState();
    _data = widget.dataNotifier.value;
    widget.dataNotifier.addListener(_onChapterChanged);
    _itemPositionsListener.itemPositions.addListener(_onWebtoonScroll);
    AppSystemUi.applyReader();
    if (AppSettings.volTurn) {
      VolumeKeys.enable(up: _volBack, down: _volForward);
    }
    _initChapter();
  }

  void _volBack() {
    if (_isWebtoon) {
      _jumpTo(_page - 1);
    } else {
      _turnPage(-1);
    }
  }

  void _volForward() {
    if (_isWebtoon) {
      _jumpTo(_page + 1);
    } else {
      _turnPage(1);
    }
  }

  void _turnPage(int delta) {
    final target = (_page + delta).clamp(1, _count);
    if (target != _page && _pageController.hasClients) {
      _pageController.animateToPage(target - 1,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _onChapterChanged() {
    if (!mounted) return;
    _saveProgress();
    setState(() {
      _data = widget.dataNotifier.value;
      _page = 1;
      _prefetchRequested = false;
      _downloading = false;
      _endHintNext = false;
      _endHintPrev = false;
    });
    _initChapter();
  }

  Future<void> _initChapter() async {
    final gen = ++_chapterGen;
    final data = _data;
    final count = data.imgUrls.length;
    if (count <= 0) return;
    if (data.initialPage == -2) {
      // 从下一章返回：直接落在末页
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && gen == _chapterGen) _jumpTo(count);
      });
    } else {
      // 控制器是复用的，先显式回到第 1 页，避免停留在上一章的页码/越界偏移
      _jumpTo(1);
      await _restoreProgress(data, gen);
    }
    if (mounted && gen == _chapterGen) _preloadAround(_page - 1);
  }

  // ---- 断点续读（方案 B：看完清零 + 恢复提示）----

  Future<void> _restoreProgress(ChapterData data, int gen) async {
    final key = 'progress_${data.chapterKey}';
    final count = data.imgUrls.length;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || gen != _chapterGen) return;
    final saved = prefs.getInt(key) ?? 0;
    if (saved >= 2 && saved < count) {
      _jumpTo(saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已跳转至上次阅读的第 $saved 页'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _saveProgress() async {
    // 同步捕获当前章节信息：原地切章时 _data/_page 会立刻被换成新章，
    // 若在 await 之后再读取，进度会写到错误的章节上
    final key = 'progress_${_data.chapterKey}';
    final page = _page;
    final count = _count;
    final prefs = await SharedPreferences.getInstance();
    if (page >= count - 1) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, page);
    }
  }

  // ---- 翻页与跳转 ----

  void _jumpTo(int page) {
    if (_count <= 0) return;
    final p = page.clamp(1, _count);
    if (_isWebtoon) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: p - 1);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _itemScrollController.isAttached) {
            _itemScrollController.jumpTo(index: p - 1);
          }
        });
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(p - 1);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(p - 1);
          }
        });
      }
    }
    setState(() => _page = p);
  }

  void _onPageChanged(int index) {
    setState(() {
      _page = index + 1;
      _endHintNext = false;
      _endHintPrev = false;
    });
    _maybePrefetch();
    _preloadAround(index);
  }

  void _onWebtoonScroll() {
    if (!_isWebtoon || !mounted) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final first = positions
        .where((p) => p.itemTrailingEdge > 0)
        .reduce((a, b) => a.index < b.index ? a : b);
    final newPage = (first.index + 1).clamp(1, _count);
    if (newPage != _page) {
      setState(() {
        _page = newPage;
        _endHintNext = false;
        _endHintPrev = false;
      });
      _maybePrefetch();
      _preloadAround(newPage - 1);
    }
  }

  /// 预载当前页之后 5 张（对应原生版 Glide preload 后 10 张，酌减）
  void _preloadAround(int index) {
    if (_data.isLocal) return;
    for (var i = index + 1; i <= index + 5 && i < _count; i++) {
      precacheImage(
        CachedNetworkImageProvider(wrapResolution(_data.imgUrls[i])),
        context,
        onError: (e, s) {},
      );
    }
  }

  /// 阅读至 80% 时静默预取下一章
  void _maybePrefetch() {
    final next = _data.nextChapterUrl;
    if (next == null || _prefetchRequested || _data.isLocal) return;
    if (_count > 0 && _page >= _count * 4 / 5) {
      _prefetchRequested = true;
      widget.onPrefetch?.call(next);
    }
  }

  void _openAdjacent(bool goNext) {
    final url = goNext ? _data.nextChapterUrl : _data.previousChapterUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经到头了~'), duration: Duration(seconds: 1)));
      return;
    }
    widget.onRequestChapter?.call(url);
  }

  /// 翻页到头继续翻 → 提示一次 → 再翻切章（对应原生版 doubleTapToast 逻辑）
  bool _handleOverscroll(OverscrollNotification n) {
    // 防止一次拖动产生的连续 overscroll 通知重复触发
    final now = DateTime.now();
    if (now.difference(_lastOverscrollAt).inMilliseconds < 600) return false;
    if (n.overscroll.abs() < 8) return false;
    _lastOverscrollAt = now;

    final towardEnd = n.overscroll > 0;
    if (towardEnd && _page >= _count) {
      if (_data.nextChapterUrl == null && !_data.isLocal) {
        _toast('已经到头了~');
      } else if (_endHintNext) {
        _endHintNext = false;
        _openAdjacent(true);
      } else {
        _endHintNext = true;
        _toast('再次滑动加载下一章');
      }
    } else if (!towardEnd && _page <= 1) {
      if (_data.previousChapterUrl == null && !_data.isLocal) {
        _toast('已经到头了~');
      } else if (_endHintPrev) {
        _endHintPrev = false;
        _openAdjacent(false);
      } else {
        _endHintPrev = true;
        _toast('再次滑动加载上一章');
      }
    }
    return false;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  // ---- 页码跳转弹窗（对应原生版 showPageInputDialog）----

  Future<void> _showPageInputDialog() async {
    final controller = TextEditingController(text: _page.toString());
    final target = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('跳转到页码'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '1 - $_count'),
          onSubmitted: (v) => Navigator.pop(c, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, int.tryParse(controller.text)),
              child: const Text('跳转')),
        ],
      ),
    );
    if (target != null) _jumpTo(target);
  }

  // ---- 下载 ----

  Future<void> _downloadChapter() async {
    if (_downloading || _data.isLocal) return;
    setState(() {
      _downloading = true;
      _downloadProgress = '0/$_count';
    });
    try {
      final ok = await Downloader.downloadImages(
        _data.title,
        '章节_${_data.uuid.length >= 8 ? _data.uuid.substring(0, 8) : _data.uuid}',
        _data.imgUrls,
        (done, total) {
          if (mounted) setState(() => _downloadProgress = '$done/$total');
        },
      );
      if (mounted) _toast(ok ? '本章下载完成' : '下载完成，部分图片失败');
    } catch (e) {
      if (mounted) _toast('下载失败：$e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ---- 模式切换 ----

  void _cycleReadMode() {
    final currentPage = _page;
    final next = switch (_readMode) { 'h' => 'v', 'v' => 'w', _ => 'h' };
    AppSettings.setReadMode(next);
    setState(() => _readMode = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(currentPage));
  }

  String get _modeLabel =>
      switch (_readMode) { 'v' => '纵向', 'w' => '条漫', _ => '横向' };

  // ---- 信息栏时钟（对应原生版 TimeThread）----

  Future<void> _updateClock() async {
    final now = DateTime.now();
    const weeks = ['一', '二', '三', '四', '五', '六', '日'];
    var net = '';
    try {
      final results = await Connectivity().checkConnectivity();
      net = switch (results.firstOrNull) {
        ConnectivityResult.wifi => ' WIFI',
        ConnectivityResult.mobile => ' 移动数据',
        ConnectivityResult.ethernet => ' 以太网',
        ConnectivityResult.vpn => ' VPN',
        ConnectivityResult.bluetooth => ' 蓝牙',
        ConnectivityResult.none => ' 无网络',
        _ => '',
      };
    } catch (_) {}
    if (mounted) {
      setState(() {
        _clockText =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
            ' 周${weeks[now.weekday - 1]}$net';
      });
    }
  }

  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
    if (_barsVisible) {
      _updateClock();
      _clockTimer?.cancel();
      _clockTimer =
          Timer.periodic(const Duration(seconds: 22), (_) => _updateClock());
    } else {
      _clockTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _saveProgress();
    widget.dataNotifier.removeListener(_onChapterChanged);
    _itemPositionsListener.itemPositions.removeListener(_onWebtoonScroll);
    // 必须走 AppSystemUi：iOS 写回 manual 会再次出现上下黑边
    AppSystemUi.restoreBrowserFromSettings();
    VolumeKeys.disable();
    _clockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ---- 图片控件（在线/离线通用）----

  Widget _buildImage(int index, {BoxFit fit = BoxFit.contain}) {
    final src = _data.imgUrls[index];
    if (_data.isLocal) {
      return Image.file(File(src), fit: fit,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.broken_image, color: Colors.white38));
    }
    return RetryNetworkImage(url: wrapResolution(src), fit: fit);
  }

  Widget _buildViewer() {
    if (_count <= 0) {
      return const Center(
          child: Text('本章无图片', style: TextStyle(color: Colors.white54)));
    }
    if (_isWebtoon) {
      return NotificationListener<OverscrollNotification>(
        onNotification: _handleOverscroll,
        child: ScrollablePositionedList.builder(
          itemCount: _count,
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          itemBuilder: (context, index) =>
              _buildImage(index, fit: BoxFit.fitWidth),
        ),
      );
    }
    return NotificationListener<OverscrollNotification>(
      onNotification: _handleOverscroll,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: _readMode == 'v' ? Axis.vertical : Axis.horizontal,
        reverse: _readMode == 'h' && _r2l,
        itemCount: _count,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) => InteractiveViewer(
          maxScale: 4,
          child: Center(child: _buildImage(index)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(onTap: _toggleBars, child: _buildViewer()),
          if (AppSettings.showPageNum && _count > 0)
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: _showPageInputDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$_page/$_count',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
            ),
          if (_downloading)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('下载中 $_downloadProgress',
                    style: const TextStyle(
                        color: Colors.lightGreenAccent, fontSize: 12)),
              ),
            ),
          if (_barsVisible) _buildBottomBar(),
          ValueListenableBuilder<String?>(
            valueListenable: widget.loadingText,
            builder: (context, text, child) {
              if (text == null) return const SizedBox.shrink();
              return Container(
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
                          Text(text),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (widget.onClose != null)
                    IconButton(
                      tooltip: '退出阅读',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 22),
                      onPressed: widget.onClose,
                    ),
                  Expanded(
                    child: Text(_data.title,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(_clockText,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _data.previousChapterUrl == null
                        ? null
                        : () => _openAdjacent(false),
                    child: const Text('上一章'),
                  ),
                  Expanded(
                    child: _count <= 0
                        ? const SizedBox.shrink()
                        : Slider(
                            value: _page
                                .toDouble()
                                .clamp(1, _count.toDouble()),
                            min: 1,
                            max: _count.toDouble(),
                            divisions: _count > 1 ? _count - 1 : null,
                            onChanged: (v) => _jumpTo(v.round()),
                          ),
                  ),
                  TextButton(
                    onPressed: _data.nextChapterUrl == null
                        ? null
                        : () => _openAdjacent(true),
                    child: const Text('下一章'),
                  ),
                ],
              ),
              // 窄屏下 4 个 TextButton.icon 会溢出（OVERFLOWED BY ~21px），改紧凑工具钮
              Row(
                children: [
                  Expanded(
                    child: _ReaderToolBtn(
                      icon: Icons.chrome_reader_mode,
                      label: _modeLabel,
                      onPressed: _cycleReadMode,
                    ),
                  ),
                  Expanded(
                    child: _ReaderToolBtn(
                      icon: Icons.swap_horiz,
                      label: _r2l ? '右开' : '左开',
                      onPressed: _readMode != 'h'
                          ? null
                          : () {
                              final p = _page;
                              AppSettings.setR2l(!_r2l);
                              setState(() => _r2l = !_r2l);
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) => _jumpTo(p));
                            },
                    ),
                  ),
                  Expanded(
                    child: _ReaderToolBtn(
                      icon: AppSettings.volTurn
                          ? Icons.volume_up
                          : Icons.volume_off,
                      label: '音量',
                      onPressed: () async {
                        await AppSettings.setVolTurn(!AppSettings.volTurn);
                        if (AppSettings.volTurn) {
                          VolumeKeys.enable(up: _volBack, down: _volForward);
                        } else {
                          VolumeKeys.disable();
                        }
                        setState(() {});
                      },
                    ),
                  ),
                  if (!_data.isLocal)
                    Expanded(
                      child: _ReaderToolBtn(
                        icon: Icons.download,
                        label: '下载',
                        onPressed: _downloading ? null : _downloadChapter,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 阅读器底栏紧凑工具钮，避免窄屏 TextButton.icon 横向溢出
class _ReaderToolBtn extends StatelessWidget {
  const _ReaderToolBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? Colors.white : Colors.white38;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
