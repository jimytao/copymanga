/// 章节边界二次确认换章（对齐原生 PagesManager isEndL/isEndR）。
enum ChapterEdgeOutcome { confirmNeeded, openChapter, atEnd }

class ChapterEdgeGuard {
  bool _hintNext = false;
  bool _hintPrev = false;

  ChapterEdgeOutcome onEdge(bool goNext, {required bool hasAdjacent}) {
    if (!hasAdjacent) {
      return ChapterEdgeOutcome.atEnd;
    }
    if (goNext ? _hintNext : _hintPrev) {
      if (goNext) {
        _hintNext = false;
      } else {
        _hintPrev = false;
      }
      return ChapterEdgeOutcome.openChapter;
    }
    if (goNext) {
      _hintNext = true;
    } else {
      _hintPrev = true;
    }
    return ChapterEdgeOutcome.confirmNeeded;
  }

  void clear() {
    _hintNext = false;
    _hintPrev = false;
  }

  void clearSide(bool goNext) {
    if (goNext) {
      _hintNext = false;
    } else {
      _hintPrev = false;
    }
  }
}

/// 一次 pointer 手势内只放行一次越界计数，避免同一次拖动的连续 overscroll 重复触发。
class EdgeGestureGate {
  bool _consumed = true;

  void beginGesture() {
    _consumed = false;
  }

  bool allow() {
    if (_consumed) return false;
    _consumed = true;
    return true;
  }
}
