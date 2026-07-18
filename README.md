<div align="center">
  <img src="assets/icon.png" width="112" alt="Pulsar 图标">
  <h1>Pulsar · 脉冲星训练星系</h1>
  <p>把每周计划、每组训练与成长事项，变成一片可以点亮的动态星海。</p>

  [![Android APK](https://github.com/YXX168/Pulsar/actions/workflows/android.yml/badge.svg)](https://github.com/YXX168/Pulsar/actions/workflows/android.yml)
  [![Latest Release](https://img.shields.io/github/v/release/YXX168/Pulsar?label=%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC)](https://github.com/YXX168/Pulsar/releases/latest)
  [![Flutter](https://img.shields.io/badge/Flutter-Android-54C5F8?logo=flutter)](https://flutter.dev/)
  [![MIT License](https://img.shields.io/badge/%E5%BC%80%E6%BA%90%E8%AE%B8%E5%8F%AF-MIT-7C8CF8)](LICENSE)
</div>

## 项目简介

Pulsar 是一款使用 Flutter 构建的 Android 训练计划与健身记录应用。它没有信息流、广告和饮食负担，而是以脉冲星、液态流光、轨道与裂变动画呈现每周计划。

应用提供两种共享数据的显示方式：

- **星环模式**：总核心裂变为七颗日星球，再展开当天的训练星群。
- **脉冲矩阵**：用更紧凑的看板快速切换日期、查看计划与完成度。

## 核心能力

### 训练与计划

- 每个项目按组点亮，一次点击代表完成一组。
- 项目完成后连续确认两次即可重置，无额外刷新按钮。
- 支持训练、阅读、学习、AI 创造与恢复事项。
- 支持浏览历史或未来周次，以及仅对当前周跳过某一天。
- 可配置动作顺序、组数、次数、重量、备注和组间休息时间。

### 记录与复盘

- 长按项目可记录实际次数、重量、RPE 和单组备注。
- 训练报告按动作聚合每一组数据，并支持编辑或删除。
- 提供累计组数、活跃天数、连续天数、训练容量、个人纪录和活跃热力场。
- 删除或撤销记录时，项目完成度会同步回退。

### 视觉与交互

- `CustomPainter` 绘制液态光团、能量流、体积雾、动态星环与脉冲波。
- 连贯的核心裂变、星群回收和页面返回动画。
- 原生 Android 震动反馈与高刷新率显示模式。
- 静谧、流畅、极致三档动态效果。

### 本地数据

- 计划、进度与历史保存在设备本地 SQLite 数据库。
- 支持旧版本数据自动迁移。
- 支持通过系统文件选择器导出和恢复完整 JSON 备份。
- 无账号体系，不上传训练数据；卸载前请先导出备份。

## 下载与安装

请从 [最新 Release](https://github.com/YXX168/Pulsar/releases/latest) 下载 APK：

| 安装包 | 适用设备 | 建议 |
| --- | --- | --- |
| `arm64-v8a` | 绝大多数现代 Android 手机和平板 | **推荐，体积最小** |
| 通用 APK | 不确定设备架构时使用 | 兼容性最好，体积较大 |
| `armeabi-v7a` | 较旧的 32 位 Android 设备 | 仅旧设备使用 |
| `x86_64` | Android 模拟器或少量 x86 设备 | 普通手机不要下载 |

当前要求 Android 7.0 或更高版本。相同签名版本可直接覆盖安装，计划与训练记录会保留。

## 快速使用

1. 在“计划”页面设置每周训练或成长事项。
2. 在星环模式点击总核心，选择当天星球进入训练星群。
3. 每完成一组，点击对应项目光球一次。
4. 长按项目光球可补充重量、次数、RPE 与备注。
5. 在“记录”页面查看趋势和训练报告。
6. 在“计划”页面定期导出本地备份。

## 技术实现

- Flutter / Dart
- Material 3
- CustomPainter 动态光球与星系场景
- SQLite + SharedPreferences
- 原生 Kotlin 高刷新率适配
- GitHub Actions 自动分析、测试、签名、构建与发布 APK

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

项目主要目录：

```text
lib/models/      训练计划与记录模型
lib/services/    SQLite、本地设置与数据迁移
lib/widgets/     液态光球和星系绘制组件
android/         Android 原生工程与签名配置
test/            交互与数据回归测试
```

发布签名通过 GitHub Actions Secrets 注入，仓库中不包含私钥或密码。

## 参与维护

- 提交问题前请查看 [Issue 模板](https://github.com/YXX168/Pulsar/issues/new/choose)。
- 代码贡献请阅读 [贡献指南](CONTRIBUTING.md)。
- 安全问题请按 [安全说明](SECURITY.md) 私下反馈，不要公开敏感细节。
- 版本变化记录见 [CHANGELOG](CHANGELOG.md)。

## 开源许可

Pulsar 使用 [MIT License](LICENSE) 开源。视觉灵感来自脉冲星、液态流光与轨道系统，代码与交互均为独立实现。
