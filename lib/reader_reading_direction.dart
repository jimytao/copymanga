import 'package:flutter/painting.dart';

import 'reader_gesture_config.dart';

/// 阅读方向意图：相对「下一页 / 上一页 / 下一章 / 上一章」。
enum ReadingNavIntent {
  none,
  towardNextPage,
  towardPreviousPage,
  towardNextChapter,
  towardPreviousChapter,
}

/// 物理主轴方向（屏幕坐标，不受 reverse 影响）。
enum PhysicalAxisSwipe { none, left, right, up, down }

/// 单一方向映射：物理滑动 → 页/章导航意图。
///
/// 约定（与当前 PageView 实测一致）：
/// - 横向：手指左滑 (dx&lt;0) → towardNextPage；右滑 → towardPreviousPage。
///   `PageView.reverse`（右开本）只改变内容排布与拖动物理感受，不反转「左滑=下一页」语义。
/// - 纵向：上滑 (dy&lt;0) → towardNextPage；下滑 → towardPreviousPage。
/// - [r2l] 影响点击分区左右对调，不改变上述滑动→页方向映射。
class ReaderReadingDirection {
  const ReaderReadingDirection._();

  static PhysicalAxisSwipe physicalSwipe({
    required double totalDx,
    required double totalDy,
    required bool horizontalReading,
  }) {
    if (horizontalReading) {
      if (totalDx.abs() < 0.5 && totalDy.abs() < 0.5) {
        return PhysicalAxisSwipe.none;
      }
      // 主轴优先：交叉轴过大时仍按主轴判方向，由调用方做比例过滤。
      if (totalDx.abs() >= totalDy.abs()) {
        return totalDx < 0 ? PhysicalAxisSwipe.left : PhysicalAxisSwipe.right;
      }
      return totalDy < 0 ? PhysicalAxisSwipe.up : PhysicalAxisSwipe.down;
    }
    if (totalDy.abs() < 0.5 && totalDx.abs() < 0.5) {
      return PhysicalAxisSwipe.none;
    }
    if (totalDy.abs() >= totalDx.abs()) {
      return totalDy < 0 ? PhysicalAxisSwipe.up : PhysicalAxisSwipe.down;
    }
    return totalDx < 0 ? PhysicalAxisSwipe.left : PhysicalAxisSwipe.right;
  }

  /// 物理滑动是否指向「下一页」方向（章内）。
  static bool isTowardNextPage({
    required PhysicalAxisSwipe swipe,
    required bool horizontalReading,
  }) {
    if (horizontalReading) {
      return swipe == PhysicalAxisSwipe.left;
    }
    return swipe == PhysicalAxisSwipe.up;
  }

  static bool isTowardPreviousPage({
    required PhysicalAxisSwipe swipe,
    required bool horizontalReading,
  }) {
    if (horizontalReading) {
      return swipe == PhysicalAxisSwipe.right;
    }
    return swipe == PhysicalAxisSwipe.down;
  }

  /// 主轴有符号位移：负值表示 towardNextPage 方向。
  static double signedPrimaryDelta({
    required double totalDx,
    required double totalDy,
    required bool horizontalReading,
  }) {
    return horizontalReading ? totalDx : totalDy;
  }

  static double primaryAbs({
    required double totalDx,
    required double totalDy,
    required bool horizontalReading,
  }) {
    return signedPrimaryDelta(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
    ).abs();
  }

  static double crossAbs({
    required double totalDx,
    required double totalDy,
    required bool horizontalReading,
  }) {
    return horizontalReading ? totalDy.abs() : totalDx.abs();
  }

  /// 将物理滑动映射为页/章意图。
  static ReadingNavIntent resolve({
    required double totalDx,
    required double totalDy,
    required bool horizontalReading,
    required bool atFirstPage,
    required bool atLastPage,
    bool requirePrimaryAxis = true,
  }) {
    final primary = primaryAbs(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
    );
    final cross = crossAbs(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
    );
    if (primary < 0.5) return ReadingNavIntent.none;
    if (requirePrimaryAxis && cross > primary * kChapterEdgeMaxCrossAxisRatio) {
      return ReadingNavIntent.none;
    }

    final swipe = physicalSwipe(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
    );
    if (swipe == PhysicalAxisSwipe.none) return ReadingNavIntent.none;

    final towardNext = isTowardNextPage(
      swipe: swipe,
      horizontalReading: horizontalReading,
    );
    if (towardNext) {
      if (atLastPage) return ReadingNavIntent.towardNextChapter;
      return ReadingNavIntent.towardNextPage;
    }
    if (isTowardPreviousPage(
      swipe: swipe,
      horizontalReading: horizontalReading,
    )) {
      if (atFirstPage) return ReadingNavIntent.towardPreviousChapter;
      return ReadingNavIntent.towardPreviousPage;
    }
    return ReadingNavIntent.none;
  }

  /// overscroll 符号 → 是否 towardEnd（下一页/下一章方向）。
  /// Flutter 约定：overscroll &gt; 0 表示沿 scroll axis 正向越界（即 towardEnd）。
  static bool overscrollTowardEnd(double overscroll) => overscroll > 0;

  /// 调试字段：与旧 SwipeDirectionFields 兼容的逻辑阅读方向标签。
  static String logicalReadingLabel({
    required double totalDx,
    required double totalDy,
    required bool horizontalReading,
  }) {
    final swipe = physicalSwipe(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
    );
    if (swipe == PhysicalAxisSwipe.none) return 'none';
    if (isTowardNextPage(swipe: swipe, horizontalReading: horizontalReading)) {
      return 'towardNext';
    }
    if (isTowardPreviousPage(
      swipe: swipe,
      horizontalReading: horizontalReading,
    )) {
      return 'towardPrevious';
    }
    return 'none';
  }

  static String physicalLabel(PhysicalAxisSwipe swipe) => switch (swipe) {
    PhysicalAxisSwipe.none => 'none',
    PhysicalAxisSwipe.left => 'left',
    PhysicalAxisSwipe.right => 'right',
    PhysicalAxisSwipe.up => 'up',
    PhysicalAxisSwipe.down => 'down',
  };

  /// 供点击分区使用：左/上区域是否为「下一页」（受 r2l 影响）。
  static bool tapLeadingMeansNext({
    required bool isHorizontal,
    required bool r2l,
  }) {
    if (!isHorizontal) return false; // 纵向：上=prev
    return r2l;
  }
}

/// 边界 swipe 几何判定（纯函数，便于单测）。
class EdgeSwipeGeometry {
  const EdgeSwipeGeometry({
    required this.accepted,
    required this.rejectReason,
    required this.intent,
    required this.primaryDistance,
    required this.velocityPrimary,
  });

  final bool accepted;
  final String rejectReason;
  final ReadingNavIntent intent;
  final double primaryDistance;
  final double velocityPrimary;

  static EdgeSwipeGeometry evaluate({
    required double totalDx,
    required double totalDy,
    required int durationMs,
    required Size viewport,
    required bool horizontalReading,
    required bool atFirstPage,
    required bool atLastPage,
    double minDistanceFraction = kChapterEdgeMinDistanceFraction,
    double minVelocity = kChapterEdgeMinVelocityLogicalPxPerSec,
  }) {
    final intent = ReaderReadingDirection.resolve(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
      atFirstPage: atFirstPage,
      atLastPage: atLastPage,
    );
    final primary = ReaderReadingDirection.primaryAbs(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
    );
    final axisLen = horizontalReading ? viewport.width : viewport.height;
    final minDist = axisLen * minDistanceFraction;
    final sec = durationMs <= 0 ? 0.001 : durationMs / 1000.0;
    final signed = ReaderReadingDirection.signedPrimaryDelta(
      totalDx: totalDx,
      totalDy: totalDy,
      horizontalReading: horizontalReading,
    );
    final velocity = signed / sec;

    if (intent != ReadingNavIntent.towardNextChapter &&
        intent != ReadingNavIntent.towardPreviousChapter) {
      return EdgeSwipeGeometry(
        accepted: false,
        rejectReason: 'notChapterEdgeIntent',
        intent: intent,
        primaryDistance: primary,
        velocityPrimary: velocity,
      );
    }

    final distanceOk = primary >= minDist;
    final velocityOk = velocity.abs() >= minVelocity;
    if (!distanceOk && !velocityOk) {
      return EdgeSwipeGeometry(
        accepted: false,
        rejectReason: 'distanceAndVelocityBelowThreshold',
        intent: intent,
        primaryDistance: primary,
        velocityPrimary: velocity,
      );
    }

    return EdgeSwipeGeometry(
      accepted: true,
      rejectReason: 'none',
      intent: intent,
      primaryDistance: primary,
      velocityPrimary: velocity,
    );
  }
}
