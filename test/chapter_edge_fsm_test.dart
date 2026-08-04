import 'package:copymanga_flutter/chapter_edge_fsm.dart';
import 'package:copymanga_flutter/reader_reading_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChapterEdgeFsm', () {
    late ChapterEdgeFsm fsm;
    var now = 1000;
    var reqSeq = 0;

    setUp(() {
      now = 1000;
      reqSeq = 0;
      ChapterEdgeFsm.resetRequestIdSeqForTest();
      fsm = ChapterEdgeFsm(
        confirmWindow: const Duration(seconds: 2),
        nowMs: () => now,
        nextRequestId: () => ++reqSeq,
      );
    });

    ChapterEdgeFsmResult swipe({
      required String session,
      required bool goNext,
      bool hasAdjacent = true,
    }) {
      return fsm.handle(
        event: ChapterEdgeFsmEvent.independentSwipeCompleted,
        goNext: goNext,
        gestureSessionId: session,
        intent: goNext
            ? ReadingNavIntent.towardNextChapter
            : ReadingNavIntent.towardPreviousChapter,
        hasAdjacent: hasAdjacent,
      );
    }

    test('尾页第一次向下一章方向 swipe → armedNext', () {
      final r = swipe(session: 'gs-1', goNext: true);
      expect(r.action, ChapterEdgeFsmAction.showConfirmHint);
      expect(r.state, ChapterEdgeFsmState.armedNext);
    });

    test('尾页第二次独立同向 swipe → 单次 switchNext', () {
      swipe(session: 'gs-1', goNext: true);
      final r = swipe(session: 'gs-2', goNext: true);
      expect(r.action, ChapterEdgeFsmAction.requestChapterSwitch);
      expect(r.state, ChapterEdgeFsmState.switchingNext);
      expect(r.chapterRequestId, 1);
      final third = swipe(session: 'gs-3', goNext: true);
      expect(third.action, ChapterEdgeFsmAction.deduplicated);
      expect(third.rejectReason, 'switchingInProgress');
    });

    test('首页对应 previous', () {
      final r1 = swipe(session: 'gs-1', goNext: false);
      expect(r1.state, ChapterEdgeFsmState.armedPrevious);
      final r2 = swipe(session: 'gs-2', goNext: false);
      expect(r2.action, ChapterEdgeFsmAction.requestChapterSwitch);
      expect(r2.state, ChapterEdgeFsmState.switchingPrevious);
    });

    test('同一个 gestureSessionId 重复事件不算第二划', () {
      swipe(session: 'gs-1', goNext: true);
      final r = swipe(session: 'gs-1', goNext: true);
      expect(r.action, ChapterEdgeFsmAction.deduplicated);
      expect(fsm.state, ChapterEdgeFsmState.armedNext);
    });

    test('第二划方向相反 → 重新武装', () {
      swipe(session: 'gs-1', goNext: true);
      final r = swipe(session: 'gs-2', goNext: false);
      expect(r.action, ChapterEdgeFsmAction.showConfirmHint);
      expect(r.state, ChapterEdgeFsmState.armedPrevious);
    });

    test('第二划超时', () {
      swipe(session: 'gs-1', goNext: true);
      now += 2500;
      final r = swipe(session: 'gs-2', goNext: true);
      // 超时后当作新的第一划
      expect(r.action, ChapterEdgeFsmAction.showConfirmHint);
      expect(r.state, ChapterEdgeFsmState.armedNext);
    });

    test('第一划后离开边界', () {
      swipe(session: 'gs-1', goNext: true);
      fsm.handle(event: ChapterEdgeFsmEvent.leftBoundary);
      expect(fsm.state, ChapterEdgeFsmState.idle);
      final r = swipe(session: 'gs-2', goNext: true);
      expect(r.action, ChapterEdgeFsmAction.showConfirmHint);
    });

    test('pointerCancel / gestureCancelled', () {
      swipe(session: 'gs-1', goNext: true);
      fsm.handle(event: ChapterEdgeFsmEvent.gestureCancelled);
      expect(fsm.state, ChapterEdgeFsmState.idle);
    });

    test('图片缩放开始重置', () {
      swipe(session: 'gs-1', goNext: true);
      fsm.handle(event: ChapterEdgeFsmEvent.imageScaleStarted);
      expect(fsm.state, ChapterEdgeFsmState.idle);
    });

    test('App 进入后台重置', () {
      swipe(session: 'gs-1', goNext: true);
      fsm.handle(event: ChapterEdgeFsmEvent.appPaused);
      expect(fsm.state, ChapterEdgeFsmState.idle);
    });

    test('switching 期间第三划去重', () {
      swipe(session: 'gs-1', goNext: true);
      swipe(session: 'gs-2', goNext: true);
      final r = swipe(session: 'gs-3', goNext: true);
      expect(r.action, ChapterEdgeFsmAction.deduplicated);
    });

    test('加载失败后恢复', () {
      swipe(session: 'gs-1', goNext: true);
      final open = swipe(session: 'gs-2', goNext: true);
      fsm.handle(
        event: ChapterEdgeFsmEvent.chapterRequestFailed,
        chapterRequestId: open.chapterRequestId,
      );
      expect(fsm.state, ChapterEdgeFsmState.idle);
      final again = swipe(session: 'gs-3', goNext: true);
      expect(again.action, ChapterEdgeFsmAction.showConfirmHint);
    });

    test('加载成功后清理', () {
      swipe(session: 'gs-1', goNext: true);
      swipe(session: 'gs-2', goNext: true);
      fsm.handle(event: ChapterEdgeFsmEvent.chapterRequestSucceeded);
      expect(fsm.state, ChapterEdgeFsmState.idle);
      expect(fsm.activeChapterRequestId, isNull);
    });

    test('旧 chapterRequestId 返回去重', () {
      swipe(session: 'gs-1', goNext: true);
      final open = swipe(session: 'gs-2', goNext: true);
      final stale = fsm.handle(
        event: ChapterEdgeFsmEvent.chapterRequestFailed,
        chapterRequestId: (open.chapterRequestId ?? 0) + 99,
      );
      expect(stale.action, ChapterEdgeFsmAction.deduplicated);
      expect(fsm.state, ChapterEdgeFsmState.switchingNext);
    });

    test('无邻章 → atEnd', () {
      final r = swipe(session: 'gs-1', goNext: true, hasAdjacent: false);
      expect(r.action, ChapterEdgeFsmAction.showAtEnd);
    });

    test('prefetch 命中路径：成功后可再次双滑', () {
      swipe(session: 'gs-1', goNext: true);
      swipe(session: 'gs-2', goNext: true);
      fsm.handle(event: ChapterEdgeFsmEvent.chapterRequestSucceeded);
      final r = swipe(session: 'gs-3', goNext: true);
      expect(r.action, ChapterEdgeFsmAction.showConfirmHint);
    });

    test('manualEdgeAction 与 swipe 共享确认语义', () {
      final r1 = fsm.handle(
        event: ChapterEdgeFsmEvent.manualEdgeAction,
        goNext: true,
        hasAdjacent: true,
      );
      expect(r1.action, ChapterEdgeFsmAction.showConfirmHint);
      final r2 = fsm.handle(
        event: ChapterEdgeFsmEvent.manualEdgeAction,
        goNext: true,
        hasAdjacent: true,
      );
      expect(r2.action, ChapterEdgeFsmAction.requestChapterSwitch);
    });

    test('auxOverscroll 第二划可换章', () {
      fsm.handle(
        event: ChapterEdgeFsmEvent.auxOverscroll,
        goNext: true,
        gestureSessionId: 'gs-a',
        intent: ReadingNavIntent.towardNextChapter,
        hasAdjacent: true,
      );
      final r = fsm.handle(
        event: ChapterEdgeFsmEvent.auxOverscroll,
        goNext: true,
        gestureSessionId: 'gs-b',
        intent: ReadingNavIntent.towardNextChapter,
        hasAdjacent: true,
      );
      expect(r.action, ChapterEdgeFsmAction.requestChapterSwitch);
    });
  });

  group('ReaderReadingDirection', () {
    test('横向左滑 → next（r2l 不影响滑动映射）', () {
      expect(
        ReaderReadingDirection.resolve(
          totalDx: -80,
          totalDy: 2,
          horizontalReading: true,
          atFirstPage: false,
          atLastPage: false,
        ),
        ReadingNavIntent.towardNextPage,
      );
      expect(
        ReaderReadingDirection.resolve(
          totalDx: -80,
          totalDy: 2,
          horizontalReading: true,
          atFirstPage: false,
          atLastPage: true,
        ),
        ReadingNavIntent.towardNextChapter,
      );
    });

    test('横向右滑 → previous', () {
      expect(
        ReaderReadingDirection.resolve(
          totalDx: 90,
          totalDy: 1,
          horizontalReading: true,
          atFirstPage: true,
          atLastPage: false,
        ),
        ReadingNavIntent.towardPreviousChapter,
      );
    });

    test('纵向上滑 → next', () {
      expect(
        ReaderReadingDirection.resolve(
          totalDx: 1,
          totalDy: -100,
          horizontalReading: false,
          atFirstPage: false,
          atLastPage: true,
        ),
        ReadingNavIntent.towardNextChapter,
      );
    });

    test('纵向下滑 → previous', () {
      expect(
        ReaderReadingDirection.resolve(
          totalDx: 0,
          totalDy: 120,
          horizontalReading: false,
          atFirstPage: true,
          atLastPage: false,
        ),
        ReadingNavIntent.towardPreviousChapter,
      );
    });
  });
}
