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
            ScrollView {
                VStack(spacing: 14) {
                    engineCard
                    languageCard

                    if translationManager.config.engineType != .apple {
                        apiCard
                    }

                    ocrCard
                    aboutCard
                }
                .padding()
            }
            .background(PTBackground())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.ptText)
                }
            }
            .sheet(isPresented: $showRegionEditor, onDismiss: {
                ocrRegion = OCRRegionConfig.load()
            }) {
                OCRRegionEditorView(region: $ocrRegion)
            }
        }
    }

    // MARK: - 引擎

    private var engineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("翻译引擎")

            Picker("翻译引擎", selection: $translationManager.config.engineType) {
                ForEach(TranslationEngineType.allCases, id: \.self) { engine in
                    Text(engine.displayName).tag(engine)
                }
            }
            .pickerStyle(.menu)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ptField))
            .onChange(of: translationManager.config.engineType) { _ in
                translationManager.saveSettings()
            }

            Text(translationManager.config.engineType == .apple
                 ? "设备端翻译免费离线(iOS 18+),首次使用需允许系统下载语言包;旧系统请改用 AI 或百度引擎。"
                 : "其他引擎需要网络连接。「智能体」对话页与截图翻译共用此配置。")
                .font(.caption)
                .foregroundColor(.ptSub)
        }
        .ptCard()
    }

    // MARK: - 语言

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("语言设置")

            labeledPicker("源语言", selection: $translationManager.config.sourceLanguage,
                          options: supportedLanguages.map { ($0.code, $0.name) }) { _ in
                translationManager.saveSettings()
            }

            labeledPicker("目标语言", selection: $translationManager.config.targetLanguage,
                          options: supportedLanguages.filter { $0.code != "auto" }.map { ($0.code, $0.name) }) { _ in
                translationManager.saveSettings()
            }

            Toggle(isOn: $translationManager.config.showBilingual) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("原文-译文对照")
                        .foregroundColor(.ptText)
                    Text("逐段显示原文和译文,关闭则只显示译文")
                        .font(.caption)
                        .foregroundColor(.ptSub)
                }
            }
            .tint(.ptAccent)
            .onChange(of: translationManager.config.showBilingual) { _ in
                translationManager.saveSettings()
            }
        }
        .ptCard()
    }

    // MARK: - API 配置

    @ViewBuilder
    private var apiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("API 配置")

            if translationManager.config.engineType == .openai {
                TextField("API 地址", text: $translationManager.config.apiEndpoint)
                    .textFieldStyle(PTTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .onChange(of: translationManager.config.apiEndpoint) { _ in
                        translationManager.saveSettings()
                    }

                SecureField("API Key", text: $translationManager.config.apiKey)
                    .textFieldStyle(PTTextFieldStyle())
                    .onChange(of: translationManager.config.apiKey) { _ in
                        translationManager.saveSettings()
                    }

                TextField("翻译/对话模型(LLM)", text: $translationManager.config.aiModel)
                    .textFieldStyle(PTTextFieldStyle())
                    .autocapitalization(.none)
                    .onChange(of: translationManager.config.aiModel) { _ in
                        translationManager.saveSettings()
                    }

                TextField("识图模型(VLM)", text: $translationManager.config.vlmModel)
                    .textFieldStyle(PTTextFieldStyle())
                    .autocapitalization(.none)
                    .onChange(of: translationManager.config.vlmModel) { _ in
                        translationManager.saveSettings()
                    }

                Text("AI 视觉提取 + 识图问答使用 VLM 槽位;对话/翻译使用 LLM 槽位。")
                    .font(.caption)
                    .foregroundColor(.ptSub)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Prompt 提示词")
                        .font(.subheadline)
                        .foregroundColor(.ptSub)
                    TextEditor(text: $translationManager.config.aiPrompt)
                        .frame(minHeight: 100)
                        .font(.caption)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ptField))
                        .foregroundColor(.ptText)
                        .onChange(of: translationManager.config.aiPrompt) { _ in
                            translationManager.saveSettings()
                        }
                }
            } else {
                SecureField("API Key", text: $translationManager.config.apiKey)
                    .textFieldStyle(PTTextFieldStyle())
                    .onChange(of: translationManager.config.apiKey) { _ in
                        translationManager.saveSettings()
                    }

                if translationManager.config.engineType == .baidu {
                    SecureField("密钥", text: $translationManager.config.apiSecret)
                        .textFieldStyle(PTTextFieldStyle())
                        .onChange(of: translationManager.config.apiSecret) { _ in
                            translationManager.saveSettings()
                        }
                }

                if translationManager.config.engineType == .tencent {
                    SecureField("SecretKey", text: $translationManager.config.apiSecret)
                        .textFieldStyle(PTTextFieldStyle())
                        .onChange(of: translationManager.config.apiSecret) { _ in
                            translationManager.saveSettings()
                        }
                }
            }
        }
        .ptCard()
    }

    // MARK: - OCR 设置

    private var ocrCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("OCR 设置")

            Button {
                haptic()
                ocrRegion = OCRRegionConfig.load()
                showRegionEditor = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("识别区域")
                            .foregroundColor(.ptText)
                        Text(ocrRegion.summaryText)
                            .font(.caption)
                            .foregroundColor(.ptSub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.ptSub)
                }
            }

            HStack {
                Text("识别频率").foregroundColor(.ptSub)
                Spacer()
                Text("每 1.5 秒").foregroundColor(.ptText)
            }
            HStack {
                Text("变化阈值").foregroundColor(.ptSub)
                Spacer()
                Text("15%").foregroundColor(.ptText)
            }
        }
        .ptCard()
    }

    // MARK: - 关于

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("关于")
            HStack {
                Text("版本").foregroundColor(.ptSub)
                Spacer()
                Text("1.2.0").foregroundColor(.ptText)
            }
            Text("截图、OCR、翻译默认尽可能在设备本地完成;云端请求直连你配置的服务商。")
                .font(.caption)
                .foregroundColor(.ptSub)
        }
        .ptCard()
    }

    // MARK: - 通用组件

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.ptText)
    }

    private func labeledPicker(
        _ title: String,
        selection: Binding<String>,
        options: [(String, String)],
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.ptSub)
            Picker(title, selection: selection) {
                ForEach(options, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
            .pickerStyle(.menu)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ptField))
            .onChange(of: selection.wrappedValue) { newValue in
                onChange(newValue)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
