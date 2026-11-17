# 贡献指南

感谢愿意为 ApexDrama 出力！本文件说明如何提交 PR，以及仓库的约定。

## 快速开始

```bash
git clone https://github.com/Sxuan-Coder/open-apex-drama.git
cd open-apex-drama
flutter pub get
flutter run                            # 调试运行（Android / Windows）
```

环境要求见 [docs/build.md](docs/build.md)。SDK 通过 git 依赖自动拉取，无需额外步骤。

## 提交 PR 前必须通过

```bash
flutter analyze                        # 零 issue
flutter test                           # 全部通过
```

PR 里请说明：动机（解决什么问题）、改动范围、你做过的验证。

## 分支与提交约定

- 从 `master` 拉功能分支，命名 `feat/xxx`、`fix/xxx`、`docs/xxx`
- Commit message 用 `类型: 描述`（参考现有历史）：`feat:` `fix:` `docs:` `chore:` `refactor:`
- 一个 PR 聚焦一件事，大改动先开 issue 讨论

## 代码约定

- 行文与注释中平台一律称「水果」，不直接点名；SDK 相关表述用「端侧 SDK」「水果端 SDK」
- 不引入任何签名材料（keystore / key.properties / 密码）、密钥、本机绝对路径——
  `.gitignore` 会拦截 `*.jks` / `*.keystore` / `key.properties`，PR 里也不允许出现
- 主题色使用 `theme/app_colors.dart` 的语义化令牌（ThemeExtension），不写死颜色
- UI 文案中文，代码标识符英文

## 特别欢迎：iOS

`ios/` 工程文件已就位，但维护者目前只在 Android / Windows 构建发版，**iOS 从未经过构建验证**。
有 Mac 环境的欢迎提 PR：构建验证、签名配置说明、Xcode 工程适配、Bug 修复都非常有价值。

## SDK 版本

SDK（`openhongguo`）是 git 依赖，指向维护者的 fork，`ref` 锁定 commit。
贡献者**不需要**也不应该改动该依赖的 `ref`；如果 PR 依赖 SDK 的新能力，请在 PR 描述里说明，由维护者同步 fork 后更新。

## 发版

发版由维护者执行（tag 触发构建、正式签名、发布 Release），贡献者无需关心。
版本号规则见 [docs/build.md](docs/build.md)。

## 协议

提交即表示你同意以 [AGPL-3.0](LICENSE) 授权你的贡献。
