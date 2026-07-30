import 'package:flutter/services.dart';

/// 触觉反馈服务，参考 Pulsar 的原生 Android 震动反馈设计。
///
/// 封装 Flutter 的 HapticFeedback API，在不同交互场景提供
/// 不同强度的震动反馈。
class Haptics {
  Haptics._();

  static bool _enabled = true;

  /// 是否启用震动反馈。
  static bool get enabled => _enabled;

  static set enabled(bool value) => _enabled = value;

  /// 选择情绪类型时触发 — 轻触反馈。
  static Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// 点击光球 / 按钮时触发 — 中等反馈。
  static Future<void> tap() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// 保存记录成功时触发 — 强烈反馈。
  static Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// 删除记录时触发 — 重反馈。
  static Future<void> heavy() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }
}
