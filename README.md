# PULSAR

一款纯 Flutter 打造的训练星系与健身记录应用。视觉灵感来自脉冲星、液态流光和轨道系统，但拥有独立的交互与视觉设计。

## 核心体验

- 一周七颗日星球，点击进入当天训练星系
- `CustomPainter` 绘制液态能量、体积雾、玻璃高光与动态星环
- 每个训练动作是一颗子星球，每点击一次完成一组
- 动作完成后再点击两次即可清零，无额外刷新按钮
- 设置页集中编辑每周计划、动作与目标组数
- 训练记录和计划通过 `shared_preferences` 保存在本机
- 原生 Android 震动反馈与 Flutter 页面转场动画

## Android APK

每次推送都会由 GitHub Actions 执行分析、测试和 Android 构建。版本标签会自动发布带 APK 的 GitHub Release。
