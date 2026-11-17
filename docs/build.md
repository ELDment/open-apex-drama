# 构建指南

## 环境要求

| 平台 | 要求 |
|---|---|
| 通用 | Flutter 稳定版（`sdk: ^3.13.7`，建议与上游 Flutter 发布节奏一致） |
| Android | Android SDK + 构建工具链（`flutter doctor` 全绿即可），运行需 Android 7.0+ |
| Windows | Visual Studio 2022「使用 C++ 的桌面开发」工作负载，运行需 Win10/11 x64 |
| Windows 打包 | 可选 Inno Setup 6（脚本在标准安装路径和 `../.tooling/InnoSetup6/` 下自动查找 ISCC，找不到时只出 zip 不出 setup.exe） |

构建配置已接入国内镜像（Gradle 腾讯源 + 阿里云 maven），见 `android/build.gradle.kts` 与 `android/settings.gradle.kts`。

## 常用命令

```bash
flutter pub get                       # 拉取依赖
flutter run                           # 调试运行
flutter analyze                       # 静态检查
flutter test                          # 单元测试
flutter build apk --release --split-per-abi  # Android：按 ABI 分包
flutter build windows --release       # Windows 产物（整目录）
powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1
                                      # Windows 打包：便携版 zip + Inno Setup 安装器（产物在 dist/）
```

## 版本号

```
pubspec.yaml: version: <major>.<minor>.<patch>+<buildNumber>
buildNumber = major*100 + minor*10 + patch      # 1.4.0 -> 140
```

- patch 固定一位数（0–9），满 9 自动进位到 minor（`1.1.9 -> 1.2.0`）
- 用脚本自增，不要手改：

```bash
powershell -ExecutionPolicy Bypass -File tool\bump_version.ps1          # patch+1
powershell -ExecutionPolicy Bypass -File tool\bump_version.ps1 -Version 1.2.0
```

## Android 签名（可选）

本地 release 构建默认使用 debug 签名，可直接安装测试。若需要正式签名：

1. 生成你自己的 keystore（**不要提交到仓库**，`.gitignore` 已拦截 `*.jks` / `*.keystore` / `key.properties`）：

   ```bash
   keytool -genkey -v -keystore <你的签名>.jks -keyalg RSA -keysize 2048 -validity 36500 -alias <别名>
   ```

2. 在 `android/` 下创建 `key.properties`（路径含中文时 Gradle 已按 UTF-8 读取）：

   ```properties
   storeFile=<keystore 绝对路径>
   storePassword=<store 密码>
   keyAlias=<别名>
   keyPassword=<key 密码>
   ```

   存在该文件时 release 构建自动切换正式签名；删除即回退 debug。

3. 校验签名：

   ```bash
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
   ```

## 产物命名约定

`update_service` 按文件名筛选 Release 资产（应用内检查更新），命名必须包含：

| 平台 | 文件名 |
|---|---|
| Android arm64 | `ApexDrama-v<版本>-arm64-v8a.apk` |
| Android armv7 | `ApexDrama-v<版本>-armeabi-v7a.apk` |
| Windows 安装器 | `ApexDrama-<版本>-windows-x64-setup.exe` |
| Windows 便携版 | `ApexDrama-<版本>-windows-x64.zip` |

APK 带 `v` 前缀，Windows 包不带。

## SDK 说明

项目通过 **git 依赖**引用水果平台短剧的非官方 SDK（Apache-2.0），指向自维护的 fork
[Sxuan-Coder/openhongguo](https://github.com/Sxuan-Coder/openhongguo)（`ref` 锁定 commit），
上游项目见 README 致谢：

- Android / iOS：预编译原生库（core.jar / libgojni.so / xcframework）随 git 依赖分发，
  `pub get` 后即可构建运行，含最新播放协议修复
- Windows：fork 内含 cgo DLL 桥接与预编译 openhongguo.dll，源码构建完整可用；
  桥接的构建说明见 fork 仓库 `bindings/flutter/windows/BUILD_DLL.md`
- 升级 SDK：在 fork 同步上游最新代码（或合入所需上游 PR）后，手动更新 `pubspec.yaml` 中该依赖的 `ref`
