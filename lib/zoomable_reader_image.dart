import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'reader_tap_zones.dart';

/// 单页可缩放图：捏合缩放 + 双击放大/还原；单击走点击分区。
///
/// 点击用 [Listener] 原始指针识别，不进手势竞技场，避免拖慢 PageView 左右滑。
/// 未放大时关闭平移，把单指滑动留给翻页。
class ZoomableReaderImage extends StatefulWidget {
  const ZoomableReaderImage({
    super.key,
    required this.child,
    required this.isHorizontal,
    required this.r2l,
    required this.onPageTurn,
    required this.onMenu,
    this.onZoomChanged,
  });

  final Widget child;
  final bool isHorizontal;
  final bool r2l;
  final void Function(bool goNext) onPageTurn;
  final VoidCallback onMenu;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<ZoomableReaderImage> createState() => _ZoomableReaderImageState();
}

class _ZoomableReaderImageState extends State<ZoomableReaderImage>
    with SingleTickerProviderStateMixin {
  static const _maxScale = 4.0;
  static const _doubleTapScale = 2.5;
  static const _tapSlop = 18.0;
  static const _doubleTapTimeout = Duration(milliseconds: 280);

  final _transform = TransformationController();
  late final AnimationController _anim;
  Animation<Matrix4>? _matrixAnim;
  bool _zoomed = false;

  // 原始指针点击（不进 GestureArena，不拖慢翻页）
  int _pointers = 0;
  Offset? _downPos;
  int? _downPointer;
  DateTime? _firstTapAt;
  Offset? _firstTapPos;
  bool _moved = false;
  bool _scaleInteracting = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final a = _matrixAnim;
        if (a != null) _transform.value = a.value;
      });
    _transform.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransformChanged);
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final z = _transform.value.getMaxScaleOnAxis() > 1.05;
    if (z != _zoomed) {
      setState(() => _zoomed = z);
      widget.onZoomChanged?.call(z);
    }
  }

  void _animateTo(Matrix4 target) {
    _matrixAnim = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0);
  }

  void _toggleDoubleTapZoom(Offset pos) {
    final scale = _transform.value.getMaxScaleOnAxis();
    if (scale > 1.05) {
      _animateTo(Matrix4.identity());
      return;
    }
    const s = _doubleTapScale;
    final zoomed = Matrix4.identity()
      ..translateByDouble(-pos.dx * (s - 1), -pos.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    _animateTo(zoomed);
  }

  void _handleSingleTap(Offset pos) {
    if (_zoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    switch (classifyReaderTap(
      pos,
      box.size,
      isHorizontal: widget.isHorizontal,
      r2l: widget.r2l,
    )) {
      case ReaderTapZone.menu:
        widget.onMenu();
      case ReaderTapZone.next:
        widget.onPageTurn(true);
      case ReaderTapZone.prev:
        widget.onPageTurn(false);
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers++;
    if (_pointers > 1) {
      // 多指：取消单击/双击判定，交给捏合
      _downPointer = null;
      _downPos = null;
      _firstTapAt = null;
      _firstTapPos = null;
      return;
    }
    _downPointer = e.pointer;
    _downPos = e.localPosition;
    _moved = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _downPointer || _downPos == null) return;
    if ((e.localPosition - _downPos!).distance > _tapSlop) {
      _moved = true;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _pointers = (_pointers - 1).clamp(0, 20);
    if (e.pointer != _downPointer) return;
    final down = _downPos;
    final moved = _moved;
    final scaleBusy = _scaleInteracting;
    _downPointer = null;
    _downPos = null;
    if (down == null || moved || scaleBusy || _pointers > 0) return;

    final now = DateTime.now();
    final firstAt = _firstTapAt;
    final firstPos = _firstTapPos;
    if (firstAt != null &&
        firstPos != null &&
        now.difference(firstAt) <= _doubleTapTimeout &&
        (e.localPosition - firstPos).distance <= _tapSlop * 2) {
      _firstTapAt = null;
      _firstTapPos = null;
      _toggleDoubleTapZoom(e.localPosition);
      return;
    }

    _firstTapAt = now;
    _firstTapPos = e.localPosition;
    // 等双击窗口结束再触发单击，避免双击第一下误翻页
    final scheduledPos = e.localPosition;
    final scheduledAt = now;
    Future<void>.delayed(_doubleTapTimeout, () {
      if (!mounted) return;
      if (_firstTapAt != scheduledAt || _firstTapPos != scheduledPos) return;
      _firstTapAt = null;
      _firstTapPos = null;
      _handleSingleTap(scheduledPos);
    });
  }

  void _onPointerCancel(PointerEvent e) {
    _pointers = (_pointers - 1).clamp(0, 20);
    if (e.pointer == _downPointer) {
      _downPointer = null;
      _downPos = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: _maxScale,
        // 未放大时关闭平移，单指滑动完全交给 PageView
        panEnabled: _zoomed,
        scaleEnabled: true,
        clipBehavior: Clip.hardEdge,
        onInteractionStart: (_) {
          _scaleInteracting = true;
          // 捏合开始时作废点击序列
          _firstTapAt = null;
          _firstTapPos = null;
        },
        onInteractionEnd: (_) {
          _scaleInteracting = false;
          _onTransformChanged();
          // 若松手后已回到 1x，确保外层解锁翻页
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onTransformChanged();
          });
        },
        child: SizedBox.expand(
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
