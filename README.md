# 情绪星海 EmotionGalaxy

<p align="center">
  <strong>用星空记录你的每一次情绪起伏</strong>
</p>

<p align="center">
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android-green.svg">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-blue.svg">
  <img alt="Language" src="https://img.shields.io/badge/Language-Dart-orange.svg">
</p>

---

## 简介

**情绪星海**（EmotionGalaxy）是一款专注于情绪记录与可视化的 Android 应用，使用 Flutter 框架开发。它将每一次情绪记录转化为星系中的一颗星辰，让你以全新的方式审视自己的内心世界。通过星系可视化、历史日历和统计分析，帮助你更好地理解情绪变化的规律与趋势。

应用设计灵感来源于 Pulsar 项目，强调沉浸式的视觉体验与简洁易用的交互。

## 核心功能

### 情绪记录
- 支持 **9 种情绪类型**：喜悦、平静、爱意、感恩、兴奋、低落、焦虑、愤怒、疲惫
- 提供 **5 级强度**：微弱、轻微、适中、强烈、极强，精确量化你的感受
- 可附加文字备注与标签，记录当下的心境与缘由

### 星系可视化
- 每一条情绪记录都会化作星系中的一颗星
- 基于 `CustomPainter` 自定义绘制，呈现动态星空效果
- 情绪类型决定星辰颜色，强度决定星辰亮度与大小

### 历史日历
- 以日历视图回顾每日的情绪记录
- 快速定位某一天的心境状态
- 支持按日期筛选与查看详情

### 统计分析
- 汇总情绪分布，了解情绪倾向
- 追踪情绪随时间的变化趋势
- 可视化展示情绪频率与强度统计

### 本地存储
- 采用 **SQLite** 作为主存储引擎，保障数据结构化与查询效率
- **SharedPreferences** 作为轻量级降级方案，在无 SQLite 环境下自动切换
- 所有数据完全存储于本地，保护隐私

### 备份恢复
- 支持导出全部数据为备份文件
- 可从备份文件恢复历史记录
- 轻松迁移与保护你的情绪档案

## 技术实现

| 技术领域 | 实现方案 |
| --- | --- |
| 框架与语言 | Flutter / Dart |
| 设计语言 | Material Design 3 (Material You) |
| 自定义绘制 | `CustomPainter` 实现星系粒子动画 |
| 数据存储 | SQLite + SharedPreferences 双重方案 |
| 原生层 | Kotlin (Android 平台特性接入) |
| 构建工具 | Gradle 8.10.2 (Kotlin DSL) |
| 最低系统 | Android 7.0 (API 24) |

## 本地开发

### 环境要求

- Flutter 3.x（稳定通道）
- Dart 3.x
- Android Studio / VS Code
- Android SDK（compileSdk 由 Flutter 配置，minSdk 24）
- JDK 17

### 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/YXX168/EmotionGalaxy.git
cd EmotionGalaxy

# 2. 获取依赖
flutter pub get

# 3. 静态分析
flutter analyze

# 4. 运行测试
flutter test

# 5. 在设备或模拟器上运行
flutter run
```

### 构建 APK

```bash
# Debug 版本
flutter build apk --debug

# Release 版本
flutter build apk --release
```

构建产物位于 `build/app/outputs/flutter-apk/`。

## 目录结构

```
EmotionGalaxy/
├── android/                          # Android 原生配置
│   ├── app/
│   │   ├── build.gradle.kts          # App 模块构建脚本
│   │   └── src/
│   │       ├── main/
│   │       │   ├── AndroidManifest.xml
│   │       │   ├── kotlin/com/emotion/galaxy/
│   │       │   │   └── MainActivity.kt
│   │       │   └── res/               # 资源（主题、启动背景等）
│   │       ├── debug/                # Debug 清单
│   │       └── profile/              # Profile 清单
│   ├── build.gradle.kts              # 顶层构建脚本
│   ├── settings.gradle.kts           # Gradle 设置
│   └── gradle/wrapper/               # Gradle Wrapper
├── lib/                              # Flutter 源码
│   ├── models/                       # 数据模型
│   │   ├── emotion.dart              # 情绪类型 / 调色板 / 强度等级
│   │   └── emotion_entry.dart         # 情绪记录条目 / 日摘要 / 统计
│   ├── services/                     # 业务服务
│   │   └── storage.dart              # 存储服务（SQLite + SP 降级）
│   ├── widgets/                       # 可复用组件
│   │   └── galaxy_scene.dart         # 星系场景与粒子爆发绘制
│   └── pages/                         # 页面
│       ├── home_page.dart             # 首页
│       ├── record_page.dart           # 情绪记录页
│       ├── calendar_page.dart         # 历史日历页
│       └── stats_page.dart            # 统计分析页
├── test/                              # 测试
│   └── widget_test.dart               # Widget 与单元测试
├── .github/                           # GitHub 配置
│   ├── workflows/android.yml         # CI 工作流
│   └── ISSUE_TEMPLATE/                # Issue 模板
├── pubspec.yaml                       # Flutter 依赖配置
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
└── SECURITY.md
```

## 开源许可

本项目基于 [MIT License](./LICENSE) 开源，版权所有 2026 YXX168。

欢迎贡献代码、提交 Issue 或参与讨论。
