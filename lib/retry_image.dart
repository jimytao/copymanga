import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'image_cache_store.dart';

/// 带自动重试的网络图片：失败后 1.5s/3s 退避自动重试 2 次
/// （对应原生版 loadImageWithRetry），仍失败则显示碎图，点按手动重试。
class RetryNetworkImage extends StatefulWidget {
  const RetryNetworkImage({
    super.key,
    required this.url,
    this.fit,
    this.onIntrinsicSize,
  });

  final String url;
  final BoxFit? fit;

  /// 图片解码完成后回报原始像素尺寸。条漫用它缓存宽高比，
  /// 让 item 高度在图片被回收/重建时保持不变（否则会塌陷回跳）。
  final ValueChanged<Size>? onIntrinsicSize;

  @override
  State<RetryNetworkImage> createState() => _RetryNetworkImageState();
}

class _RetryNetworkImageState extends State<RetryNetworkImage> {
  int _attempt = 0;
  bool _retryScheduled = false;

  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;

  @override
  void initState() {
    super.initState();
    _listenForSize();
  }

  @override
  void didUpdateWidget(RetryNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _stopListeningForSize();
      _listenForSize();
    }
  }

  @override
  void dispose() {
    _stopListeningForSize();
    super.dispose();
  }

  /// 用同一个 provider 再 resolve 一次只为拿原始尺寸：命中的是同一条
  /// ImageCache 记录，不会产生额外下载。
  void _listenForSize() {
    if (widget.onIntrinsicSize == null) return;
    final provider = CachedNetworkImageProvider(
      widget.url,
      cacheManager: AppImageCache.manager,
    );
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted) widget.onIntrinsicSize?.call(size);
    }, onError: (_, _) {});
    _sizeStream = stream;
    _sizeListener = listener;
    stream.addListener(listener);
  }

  void _stopListeningForSize() {
    final stream = _sizeStream;
    final listener = _sizeListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _sizeStream = null;
    _sizeListener = null;
  }

  void _scheduleRetry() {
    if (_retryScheduled) return;
    _retryScheduled = true;
    Future.delayed(Duration(milliseconds: 1500 * (_attempt + 1)), () async {
      await AppImageCache.manager.removeFile(widget.url);
      if (mounted) {
        setState(() {
          _attempt++;
          _retryScheduled = false;
        });
      }
    });
  }

  void _manualRetry() async {
    await AppImageCache.manager.removeFile(widget.url);
    if (mounted) setState(() => _attempt = 0);
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      cacheManager: AppImageCache.manager,
      fit: widget.fit,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (context, url, error) {
        if (_attempt < 2) {
          _scheduleRetry();
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return GestureDetector(
          onTap: _manualRetry,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white38, size: 40),
                SizedBox(height: 8),
                Text(
                  '加载失败，点击重试',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
