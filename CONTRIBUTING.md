# 贡献指南

首先，感谢你对 **情绪星海（EmotionGalaxy）** 项目的关注！无论是提交 Bug 报告、提出功能建议，还是直接贡献代码，你的参与都对本项目至关重要。

本指南将帮助你顺利地参与项目开发。

## 行为准则

参与本项目即代表你同意保持友善与尊重的交流态度。我们期望所有贡献者共同维护一个开放、包容的社区环境。任何形式的人身攻击、骚扰或歧视行为都将不被容忍。

## 如何贡献

### 报告 Bug

- 在提交 Bug 报告前，请先搜索 [现有 Issue](https://github.com/YXX168/Pulsar/issues)，确认该问题是否已被报告。
- 使用项目提供的 **Bug 报告模板** 创建新 Issue，并尽可能详细地填写复现步骤、期望行为与实际行为。
- 附上相关的日志、截图以及你的运行环境信息（Flutter 版本、Android 设备等）。

### 提出功能建议

- 同样请先搜索现有 Issue，避免重复提交。
- 使用 **功能请求模板** 创建新 Issue，清晰描述你希望解决的问题与期望的解决方案。
- 请在 [Issues](https://github.com/YXX168/Pulsar/issues) 中说明建议的使用场景。

### 贡献代码

1. **Fork 仓库**：将项目 Fork 到你自己的 GitHub 账户。

2. **克隆到本地**：

   ```bash
   git clone https://github.com/<你的用户名>/Pulsar.git
   cd Pulsar
   ```

3. **创建分支**：请基于 `main` 分支创建新的功能分支。

   ```bash
   git checkout -b feature/你的功能描述
   ```

4. **安装依赖**：

   ```bash
   flutter pub get
   dart run flutter_launcher_icons
   ```

5. **编写代码**：遵循下方的代码规范。

6. **测试**：确保所有测试通过，并为新增功能编写测试。

   ```bash
   flutter analyze
   flutter test
   ```

7. **提交更改**：使用清晰的提交信息。

   ```bash
   git add .
   git commit -m "feat: 添加情绪记录的快捷选择功能"
   ```

8. **推送并创建 Pull Request**：

   ```bash
   git push origin feature/你的功能描述
   ```

   随后在 GitHub 上创建 Pull Request，目标分支为 `main`。

## 代码规范

### Dart 代码

- 遵循 [Dart 官方代码风格指南](https://dart.dev/guides/language/effective-dart/style)。
- 使用 `dart format lib test` 格式化代码。
- 提交前运行 `flutter analyze`，确保无静态分析错误。
- 为公开的类与方法编写文档注释（`///`）。

### 提交信息

推荐遵循 [约定式提交](https://www.conventionalcommits.org/zh-hans/v1.0.0/) 规范：

- `feat:` 新功能
- `fix:` Bug 修复
- `docs:` 文档变更
- `style:` 代码格式调整（不影响功能）
- `refactor:` 代码重构
- `test:` 测试相关
- `chore:` 构建、工具等杂项

示例：

```
feat: 支持按情绪类型筛选日历
fix: 修复暗色模式下星辰颜色显示异常
docs: 补充存储服务的 API 说明
```

### 分支命名

- 功能分支：`feature/简短描述`
- 修复分支：`fix/简短描述`
- 文档分支：`docs/简短描述`

## 测试要求

- 新增或修改的功能必须附带相应的测试。
- 测试代码位于 `test/` 目录，结构与 `lib/` 保持对应。
- 测试应在本地通过后再提交 Pull Request：

  ```bash
  flutter test
  ```

## Pull Request 流程

1. 确保 Pull Request 标题与描述清晰，关联相关 Issue（如 `Closes #12`）。
2. 确保 CI 检查（`flutter analyze` 与 `flutter test`）通过。
3. 保持单个 Pull Request 聚焦于单一功能或问题，避免混合不相关的更改。
4. 维护者会在收到 Pull Request 后尽快进行 Code Review，请留意可能的修改建议。
5. 评审通过后，你的更改将被合并到 `main` 分支。

## 项目结构

详细的目录结构说明请参阅 [README.md](./README.md) 中的「目录结构」一节。在添加新功能时，请将文件放置在对应的目录下：

- `lib/models/` — 数据模型
- `lib/services/` — 业务服务
- `lib/widgets/` — 可复用组件
- `lib/pages/` — 页面

## 获取帮助

如果你在贡献过程中遇到任何问题，欢迎：

- 在 [Issues](https://github.com/YXX168/Pulsar/issues) 中提问。
- 在相关 Issue 下留言。

再次感谢你的贡献！
