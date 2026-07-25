import 'package:flutter/material.dart';

/// 阅读器点击分区结果。
enum ReaderTapZone { prev, next, menu }

/// 横屏三分区（随右开本左右对调）；纵/条漫为顶上一页、底下一页、中央菜单。
ReaderTapZone classifyReaderTap(
  Offset pos,
  Size size, {
  required bool isHorizontal,
  required bool r2l,
}) {
  final w = size.width;
  final h = size.height;
  if (w <= 0 || h <= 0) return ReaderTapZone.menu;
  if (isHorizontal) {
    final frac = pos.dx / w;
    if (frac <= 1 / 3) {
      return r2l ? ReaderTapZone.next : ReaderTapZone.prev;
    }
    if (frac >= 2 / 3) {
      return r2l ? ReaderTapZone.prev : ReaderTapZone.next;
    }
    return ReaderTapZone.menu;
  }
  final cx = w * 0.5;
  final cy = h * 0.5;
  final mw = w * 0.38;
  final mh = h * 0.32;
  if ((pos.dx - cx).abs() < mw / 2 && (pos.dy - cy).abs() < mh / 2) {
    return ReaderTapZone.menu;
  }
  if (pos.dy >= h * 0.5) return ReaderTapZone.next;
  return ReaderTapZone.prev;
}

/// 条漫模式叠层：只识别轻点，多指/滑动不触发；不挡住下层滚动。
class ReaderTapZones extends StatefulWidget {
  const ReaderTapZones({
    super.key,
    required this.isHorizontal,
    required this.r2l,
    required this.onPageTurn,
    required this.onMenu,
  });

  final bool isHorizontal;
  final bool r2l;
  final void Function(bool goNext) onPageTurn;
  final VoidCallback onMenu;

  @override
  State<ReaderTapZones> createState() => _ReaderTapZonesState();
}

class _ReaderTapZonesState extends State<ReaderTapZones> {
  static const _tapSlop = 18.0;
  Offset? _down;
  int _pointers = 0;

  void _onTap(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    switch (classifyReaderTap(
      local,
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

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _pointers++;
        if (_pointers == 1) _down = e.localPosition;
      },
      onPointerCancel: (_) {
        _pointers = (_pointers - 1).clamp(0, 10);
        if (_pointers == 0) _down = null;
      },
      onPointerUp: (e) {
        final down = _down;
        final multi = _pointers > 1;
        _pointers = (_pointers - 1).clamp(0, 10);
        if (_pointers == 0) _down = null;
        if (multi || down == null) return;
        if ((e.localPosition - down).distance > _tapSlop) return;
        _onTap(e.localPosition);
      },
      child: const SizedBox.expand(),
    );
  }
}
