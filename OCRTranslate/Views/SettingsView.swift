import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var translationManager = TranslationManager.shared
    @State private var showRegionEditor = false
    @State private var ocrRegion = OCRRegionConfig.load()

    private let supportedLanguages: [(code: String, name: String)] = [
        ("auto", "自动检测"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁体中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("pt", "Português"),
        ("ru", "Русский"),
        ("ar", "العربية"),
        ("th", "ภาษาไทย"),
        ("vi", "Tiếng Việt"),
        ("it", "Italiano"),
        ("nl", "Nederlands"),
        ("pl", "Polski"),
        ("tr", "Türkçe"),
        ("hi", "हिन्दी"),
        ("id", "Bahasa Indonesia"),
        ("ms", "Bahasa Melayu"),
        ("sv", "Svenska"),
        ("da", "Dansk"),
        ("fi", "Suomi"),
        ("no", "Norsk"),
        ("cs", "Čeština"),
        ("el", "Ελληνικά"),
        ("he", "עברית"),
        ("hu", "Magyar"),
        ("ro", "Română"),
        ("uk", "Українська")
    ]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("翻译引擎", selection: $translationManager.config.engineType) {
                        ForEach(TranslationEngineType.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .onChange(of: translationManager.config.engineType) { _ in
                        translationManager.saveSettings()
                    }
                } header: {
                    Text("翻译引擎")
                } footer: {
                    Text("Apple 设备端翻译免费离线(iOS 18+),首次使用需允许系统下载语言包;旧系统请改用 AI 或百度引擎。其他引擎需要网络连接。")
                }

                Section("语言设置") {
                    Picker("源语言", selection: $translationManager.config.sourceLanguage) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: translationManager.config.sourceLanguage) { _ in
                        translationManager.saveSettings()
                    }

                    Picker("目标语言", selection: $translationManager.config.targetLanguage) {
                        ForEach(supportedLanguages.filter { $0.code != "auto" }, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: translationManager.config.targetLanguage) { _ in
                        translationManager.saveSettings()
                    }

                    Toggle(isOn: $translationManager.config.showBilingual) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("原文-译文对照")
                            Text("逐段显示原文和译文,关闭则只显示译文")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: translationManager.config.showBilingual) { _ in
                        translationManager.saveSettings()
                    }
                }

                if translationManager.config.engineType != .apple {
                    Section {
                        if translationManager.config.engineType == .openai {
                            aiSettingsView
                        } else {
                            cloudAPISettingsView
                        }
                    } header: {
                        Text("API 配置")
                    } footer: {
                        if translationManager.config.engineType == .openai {
                            Text("「智能体」对话页与「截图翻译」共用此 AI 配置。API 地址填主域名即可(自动补全 /v1/chat/completions),如 https://api.deepseek.com")
                        }
                    }
                }

                Section {
                    Button {
                        ocrRegion = OCRRegionConfig.load()
                        showRegionEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("识别区域")
                                Text(ocrRegion.summaryText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    HStack {
                        Text("识别频率")
                        Spacer()
                        Text("每 1.5 秒")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("变化阈值")
                        Spacer()
                        Text("15%")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("OCR 设置")
                } footer: {
                    Text("拖拽设置只影响 ScreenTranslator 扩展截取并识别的屏幕区域。")
                }

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showRegionEditor, onDismiss: {
                ocrRegion = OCRRegionConfig.load()
            }) {
                OCRRegionEditorView(region: $ocrRegion)
            }
        }
    }

    private var cloudAPISettingsView: some View {
        Group {
            SecureField("API Key", text: $translationManager.config.apiKey)
                .textContentType(.password)
                .onChange(of: translationManager.config.apiKey) { _ in
                    translationManager.saveSettings()
                }

            if translationManager.config.engineType == .baidu {
                SecureField("密钥", text: $translationManager.config.apiSecret)
                    .textContentType(.password)
                    .onChange(of: translationManager.config.apiSecret) { _ in
                        translationManager.saveSettings()
                    }
            }

            if translationManager.config.engineType == .tencent {
                SecureField("SecretKey", text: $translationManager.config.apiSecret)
                    .textContentType(.password)
                    .onChange(of: translationManager.config.apiSecret) { _ in
                        translationManager.saveSettings()
                    }
            }
        }
    }

    private var aiSettingsView: some View {
        Group {
            TextField("API 地址", text: $translationManager.config.apiEndpoint)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .onChange(of: translationManager.config.apiEndpoint) { _ in
                    translationManager.saveSettings()
                }

            SecureField("API Key", text: $translationManager.config.apiKey)
                .textContentType(.password)
                .onChange(of: translationManager.config.apiKey) { _ in
                    translationManager.saveSettings()
                }

            TextField("模型名称", text: $translationManager.config.aiModel)
                .autocapitalization(.none)
                .onChange(of: translationManager.config.aiModel) { _ in
                    translationManager.saveSettings()
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt 提示词")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $translationManager.config.aiPrompt)
                    .frame(minHeight: 120)
                    .font(.caption)
                    .onChange(of: translationManager.config.aiPrompt) { _ in
                        translationManager.saveSettings()
                    }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}