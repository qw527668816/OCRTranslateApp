# OCR 屏幕翻译

基于 Apple Vision + Apple Translation 的实时屏幕 OCR 翻译工具。通过 ReplayKit Broadcast Extension 捕获屏幕内容，自动识别文字并翻译，以画中画悬浮窗显示结果。

## 功能特性

- **实时屏幕翻译**：通过系统屏幕直播功能捕获画面，自动 OCR 识别并翻译
- **多种翻译引擎**：
  - Apple 翻译（离线，免费）
  - Google Translate
  - 百度翻译
  - 腾讯翻译
  - AI 翻译（支持 OpenAI 兼容 API，自定义地址/模型/Prompt）
- **智能 OCR**：基于 Apple Vision，支持 30+ 语言，自动去重避免重复翻译
- **多语言支持**：支持 30+ 种语言互译
- **完全离线可用**：使用 Apple 翻译引擎时无需网络

## 使用方法

1. 安装 App 后打开
2. 点击「开始屏幕翻译」按钮
3. 在弹出的系统菜单中选择「开始直播」
4. 切换到需要翻译的应用
5. 翻译结果将自动显示
6. 使用完毕后点击「停止翻译」

## 构建方式

### GitHub Actions（推荐）

1. Fork 本仓库
2. 推送代码到 main 分支
3. GitHub Actions 会自动构建 IPA
4. 在 Actions 的 Artifacts 中下载 IPA
5. 使用 TrollStore 安装到设备

### 本地构建

需要 macOS + Xcode 15+

```bash
git clone <repo-url>
cd OCRTranslateApp
xcodebuild -project OCRTranslate.xcodeproj -scheme OCRTranslate -configuration Release -destination "generic/platform=iOS"
```

## 翻译引擎配置

### Apple 翻译（默认）
- 无需配置，开箱即用
- 需要在「设置 > 翻译」中下载语言包以支持离线翻译

### Google Translate
- 需要 Google Cloud Translation API Key
- 在设置中填入 API Key

### 百度翻译
- 需要百度翻译开放平台的 AppID 和密钥
- 在设置中填入 AppID（API Key）和密钥（Secret）

### AI 翻译
- 需要 OpenAI 兼容的 API 地址和 Key
- 支持自定义模型名称和 Prompt
- 默认 Prompt 使用团子翻译器风格的 JSON 翻译格式

## 系统要求

- iOS 15.0+
- TrollStore 或其他签名工具安装

## 技术架构

```
用户操作 → 系统直播权限 → Broadcast Upload Extension
         ↓
    ReplayKit 推送屏幕画面
         ↓
    Apple Vision OCR 识别文字
         ↓
    文字变化检测（去重）
         ↓
    翻译引擎（Apple/Google/百度/腾讯/AI）
         ↓
    App Group 共享数据
         ↓
    主 App 读取并显示翻译结果
```

## 致谢

- Apple Vision Framework
- Apple Translation / NaturalLanguage Framework
- ReplayKit Broadcast Extension

## 许可证

MIT License
