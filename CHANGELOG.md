# 变更记录

本文件记录了情绪星海（EmotionGalaxy）的所有版本变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 计划中

- 星系可视化交互优化
- 更多统计分析维度
- 云端同步（可选）

## [1.0.0] - 2026-01-15

### 新增

- 情绪记录功能，支持 9 种情绪类型（开心、平静、悲伤、愤怒、恐惧、惊讶、厌恶、期待、焦虑）
- 5 级强度选择，精确量化情绪感受
- 文字备注功能，记录当下心境
- 星系可视化，基于 `CustomPainter` 绘制动态星空
- 历史日历视图，回顾每日情绪
- 统计分析页面，展示情绪分布与趋势
- 本地存储，采用 SQLite 为主、SharedPreferences 为降级方案
- 备份与恢复功能，支持数据导出与导入
- Material Design 3 设计语言，支持亮色与暗色主题
- Android 平台原生 Kotlin 接入
- GitHub Actions 持续集成（分析、测试、构建 APK）
- 完整的项目文档（README、贡献指南、安全说明）

### 技术栈

- Flutter / Dart
- Gradle 8.10.2（Kotlin DSL）
- Android Gradle Plugin 8.7.0
- Kotlin 2.1.0
- 最低支持 Android 7.0（API 24）
