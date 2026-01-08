# GitHub Actions 自动打包指南

本项目使用 GitHub Actions 自动打包多平台应用。

## 支持的平台

| 平台 | 输出格式 | 运行环境 |
|------|---------|---------|
| Windows | ZIP (包含 EXE 和 DLL) | windows-latest |
| Android | APK + AAB | ubuntu-latest |
| iOS | ZIP (包含 .app) | macos-latest |

## 触发自动打包

自动打包会在以下情况触发:

1. **推送到主分支**
   ```bash
   git push origin master
   ```

2. **创建版本标签** (推荐用于正式发布)
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **手动触发**
   - 访问 GitHub 仓库的 Actions 页面
   - 选择 "Build Flutter App for All Platforms"
   - 点击 "Run workflow"

4. **Pull Request**
   - 创建或更新 PR 时会自动测试构建

## 下载打包产物

### 方式一: 从 Actions 页面下载

1. 访问 GitHub 仓库的 "Actions" 页面
2. 选择一个运行记录
3. 滚动到页面底部的 "Artifacts" 区域
4. 下载所需平台的压缩包

### 方式二: 从 Release 下载 (仅限标签推送)

1. 访问 GitHub 仓库的 "Releases" 页面
2. 选择对应的版本标签
3. 下载附件:
   - `app-release.apk` - Android 安装包
   - `app-release.aab` - Android App Bundle (用于上传到 Google Play)
   - `flutter_player-ios.zip` - iOS 应用
   - `flutter_player-windows.zip` - Windows 应用

## 本地打包

如果你想在本地打包,请确保已配置相应的开发环境:

### Windows
```bash
flutter build windows --release
# 输出: build/windows/x64/runner/Release/
```

### Android
```bash
# 需要先安装 Android SDK 和 Android Studio
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk

flutter build appbundle --release
# 输出: build/app/outputs/bundle/release/app-release.aab
```

### iOS (需要 macOS)
```bash
# 需要先安装 Xcode 和 CocoaPods
flutter build ios --release
# 输出: build/ios/iphoneos/Runner.app
```

## 常见问题

### Q: Android 打包失败?
A: 确保 `pubspec.yaml` 中包含了 `media_kit_libs_android_video` 依赖。

### Q: iOS 打包失败?
A: iOS 打包必须在 macOS 上进行,Windows 无法构建 iOS 应用。

### Q: 如何自定义 Flutter 版本?
A: 编辑 `.github/workflows/build-all-platforms.yml`,修改 `flutter-version` 字段。

### Q: 如何配置代码签名?
A: 需要在 GitHub 仓库的 Secrets 中添加签名证书,并修改 workflow 配置。具体步骤请参考:
- iOS: [iOS 代码签名配置](https://help.github.com/en/actions/automating-workflows-with-github-actions/signing-commits)
- Android: [Android APK 签名](https://developer.android.com/studio/build/building-cmdline#sign_cmdline)

## 环境要求

### GitHub Actions 自动环境
- ✅ 所有平台环境已配置完毕
- ✅ 无需本地配置
- ✅ 支持并行构建

### 本地开发环境
- **Windows**: Visual Studio 2022 + Flutter SDK
- **Android**: Android SDK + Android Studio
- **iOS**: macOS + Xcode (仅 macOS)
